package Games::Lacuna::Task::Automator::Bleeder;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Automator);
with qw(Games::Lacuna::Task::Role::Notify);

sub description {
    return q[This task reports bleeders];
}

has 'known_bleeder' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    lazy_build      => 1,
    traits          => ['Array','NoIntrospection'],
    handles         => {
        add_known_bleeder  => 'push',
    }
);

has 'new_bleeder' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    default         => sub { [] },
    traits          => ['Array','NoIntrospection'],
    handles         => {
        add_new_bleeder    => 'push',
        has_new_bleeder   => 'count',
    }
);

sub _build_known_bleeder {
    my ($self) = @_;
    
    my $bleeder = $self->lookup_cache('report/known_bleeder');
    $bleeder ||= [];
    
    return $bleeder;
}

after 'run' => sub {
    my ($self) = @_;
    
    if ($self->has_new_bleeder) {
        
        $self->add_known_bleeder(map { $_->{id} } @{$self->new_bleeder});
        
        my $message = join ("\n",map { 
            sprintf('%s: Found deployed bleeder level %i',$_->{planet},$_->{level})
        } @{$self->new_bleeder});
        
        my $empire_name = $self->lookup_cache('config')->{name};
        
        $self->notify(
            "[$empire_name] Bleeders detected!",
            $message
        );
        
        $self->write_cache(
            key     => 'report/known_bleeder',
            value   => $self->known_bleeder,
            max_age => (60*60*24*7), # Cache one week
        );
    }
};

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get space port
    my @bleeders = $self->find_building($planet_stats->{id},'DeployedBleeder');
    
    return 
        unless scalar @bleeders;
    
    foreach my $bleeder (@bleeders) {
        $self->log('warn','Found deployed bleeder at %s',$planet_stats->{name});
        
        # Check if we already know this ship
        next
            if $bleeder->{id} ~~ $self->known_bleeder;
        
        $self->add_new_bleeder({
            planet  => $planet_stats->{name},
            id      => $bleeder->{id},
            level   => $bleeder->{level},
        });
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;