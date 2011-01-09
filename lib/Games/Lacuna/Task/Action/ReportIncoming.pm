package Games::Lacuna::Task::Action::ReportIncoming;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);

sub description {
    return q[This task reports incoming foreign ships];
}

has 'known_incoming' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    lazy_build      => 1,
    traits          => ['Array'],
    handles         => {
        add_known_incoming  => 'push',
    }
);

has 'new_incoming' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    default         => sub { [] },
    traits          => ['Array'],
    handles         => {
        add_new_incoming    => 'push',
        has_new_incoming   => 'count',
    }
);

sub _build_known_incoming {
    my ($self) = @_;
    
    my $incoming = $self->lookup_cache('ships/known_incoming');
    $incoming ||= [];
    
    return $incoming;
}


after 'run' => sub {
    my ($self) = @_;
    
    if ($self->has_new_incoming) {
        
        $self->add_known_incoming(map { $_->{id} } @{$self->new_incoming});
        
        $self->write_cache(
            key     => 'ships/known_incoming',
            value   => $self->known_incoming,
            max_age => (60*60*24*7), # Cache one week
        );
        
        my $message = join ("\n",map { 
            sprintf('%s: %s from %s in %s (%s %s)',$_->{planet},$_->{ship},$_->{from_empire},$_->{arrives}->ymd('.'),$_->{arrives}->hms(':'))
        } @{$self->new_incoming});
        
        $self->notify(
            "Incoming ship(s) detected!",
            $message
        );
    }
};


sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'Space Port');
    
    return 
        unless $spaceport;
    
    my $spaceport_object = $self->build_object($spaceport);
    
    # Get all incoming ships
    my $ships_data = $self->paged_request(
        object  => $spaceport_object,
        method  => 'view_foreign_ships',
        total   => 'number_of_ships',
        data    => 'ships',
    );
    
    my @incoming_ships;
    
    foreach my $ship (@{$ships_data->{ships}}) {
        my $from;
        if (defined $ship->{from}
            && defined $ship->{from}{empire}) {
            # My own ship
            next 
                if ($ship->{from}{empire}{id} == $planet_stats->{empire}{id});
            $from = $ship->{from}{empire}{name};
        }
        
        # Ignore cargo ships since they are probably carrying out a trade
        # (not dories since they can be quite stealthy and therefore can be used to carry spies)
        next
            if ($ship->{type} ~~ [qw(hulk cargo_ship galleon barge freighter)]);
        
        my $arrives = $self->parse_date($ship->{arrives});
        
        my $incoming = {
            arrives_delta   => $self->delta_date($arrives),
            arrives         => $arrives,
            planet          => $planet_stats->{name},
            ship            => $ship->{type},
            from_empire    => ($from || 'unknown'),
            id              => $ship->{id},
        };
        
        $self->log('warn','Incoming %s from %s arriving in % detected on %s',$incoming->{ship},$incoming->{from_empire},$incoming->{arrives_delta} ,$planet_stats->{name});
        
        # Check if we already know this ship
        next
            if $ship->{id} ~~ $self->known_incoming;
            
        $self->add_new_incoming($incoming);
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;