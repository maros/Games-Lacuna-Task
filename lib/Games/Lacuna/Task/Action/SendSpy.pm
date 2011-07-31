package Games::Lacuna::Task::Action::SendSpy;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);

has 'from' => (
    isa         => 'Str',
    is          => 'ro',
    required    => 1,
);

has 'to' => (
    isa         => 'Str',
    is          => 'ro',
    required    => 1,
);

has 'spy_name' => (
    isa         => 'Str',
    is          => 'ro',
    predicate   => 'has_spy_name',
);

has 'spy_count' => (
    isa         => 'Int',
    is          => 'ro',
    required    => 1,
    default     => 1,
);

has 'best_spy' => (
    isa         => 'Bool',
    is          => 'ro',
    required    => 1,
    default     => 1,
);

sub description {
    return q[Send a spy to another planet];
}

sub run {
    my ($self) = @_;
    my $planet_from = $self->body_status($self->from);
    my $planet_to = $self->body_status($self->to);
    
    # Get planet
    return $self->log('error','Could not find planet "%s"',$self->from)
        unless (defined $planet_from);
    
    # Get intelligence ministry
    my ($intelligence_ministry) = $self->find_building($planet_from->{id},'Intelligence');
    return $self->log('error','Could not find intelligence ministry')
        unless (defined $intelligence_ministry);
    
    # Get spaceport
    my ($spaceport) = $self->find_building($planet_from->{id},'Spaceport');
    return $self->log('error','Could not find spaceport')
        unless (defined $spaceport);
        
    my $intelligence_ministry_object = $self->build_object($intelligence_ministry);
    my $spaceport_object = $self->build_object($spaceport);
    
    my $spy_data = $self->paged_request(
        object  => $intelligence_ministry_object,
        method  => 'view_spies',
        total   => 'spy_count',
        data    => 'spies',
    );
    my $spy_name = $self->spy_name;
    
    my @spies;
    SPY:
    foreach my $spy (@{$spy_data->{spies}}) {
        next SPY
            unless scalar @{$spy->{possible_assignments}};
        next SPY
            unless $spy->{assigned_to}{body_id} == $planet_from->{id};
        if ($self->has_spy_name) {
            push(@spies,$spy)
                if $self->{name} =~ m/\b($spy_name)\b/;
        } else {
            push(@spies,$spy);
        }
    }
    
    if ($self->best_spy) {
        @spies = sort { $b->{offense_rating} <=> $a->{offense_rating} } @spies;
    } else {
        @spies = sort { $a->{offense_rating} <=> $b->{offense_rating} } @spies;
    }
    
    my @send_spies;
    foreach (1..$self->spy_count) {
        last
            if scalar @spies == 0;
        push(@send_spies,shift(@spies));
    }
    
    return $self->log('error','Could not find spies to send')
        unless (scalar @send_spies);
    
    
    $self->log('debug','got spies %s',\@send_spies);
    
    # TODO get body id
    
#    my $star_info = $self->request(
#        object  => $self->build_object('Map'),
#        params  => [ 283,29 ],
#        method  => 'get_star_by_xy',
#    );
#    
#    warn $star_info
#    
#    
#    
#    my $send_data = $self->request(
#        object  => $spaceport_object,
#        method  => 'get_ships_for',
#        params  => [$planet_from->{id},{ "x" => 283, "y" => 29 }],
#    );
#    
#    die $send_data;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;