package Games::Lacuna::Task::Action::SendSpy;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Stars',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['target_planet','home_planet'] };

has 'spy_name' => (
    isa         => 'Str',
    is          => 'ro',
    predicate   => 'has_spy_name',
    documentation=> q[Name of spy to be sent],
);

has 'spy_count' => (
    isa         => 'Int',
    is          => 'ro',
    required    => 1,
    default     => 1,
    documentation=> q[Number of spies to be sent],
);

has 'best_spy' => (
    isa         => 'Bool',
    is          => 'ro',
    required    => 1,
    default     => 1,
    documentation=> q[Send best available spy],
);

sub description {
    return q[Send a spy to another planet];
}

sub run {
    my ($self) = @_;
    my $planet_home = $self->home_planet_data();
    my $planet_target = $self->target_planet_data();
    
    # Get spaceport
    my ($spaceport) = $self->find_building($planet_home->{id},'Spaceport');
    return $self->log('error','Could not find spaceport')
        unless (defined $spaceport);
    my $spaceport_object = $self->build_object($spaceport);

    my $sendable_spies = $self->request(
        object      => $spaceport_object,
        method      => 'prepare_send_spies',
        params      => [$planet_target->{id},$planet_home->{id}],
    );
    
    unless (scalar @{$sendable_spies->{spies}}) {
        $self->log('err','No spies available to send');
        return;
    }
#    
#    
#    if ($self->best_spy) {
#        @spies = sort { $b->{offense_rating} <=> $a->{offense_rating} } @spies;
#    } else {
#        @spies = sort { $a->{offense_rating} <=> $b->{offense_rating} } @spies;
#    }
#    
#    my @send_spies;
#    foreach (1..$self->spy_count) {
#        last
#            if scalar @spies == 0;
#        push(@send_spies,shift(@spies));
#    }
#    
#    return $self->log('error','Could not find spies to send')
#        unless (scalar @send_spies);
#    
#    
#    $self->log('debug','got spies %s',\@send_spies);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;