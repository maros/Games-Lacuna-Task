package Games::Lacuna::Task::Action::Excavate;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars
    Games::Lacuna::Task::Role::Ships);

sub description {
    return q[This task automates building and dispatching of excavators];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get archaeology ministry
    my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology Ministry');
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'Space Port');
    
    return 
        unless $spaceport;
    return
        unless defined $archaeology_ministry;
    return
        unless $archaeology_ministry->{level} == 15;
    
    # Get available excavators
    my @avaliable_excavators = $self->ships(
        planet          => $planet_stats,
        ships_needed    => 1, # TODO: set some reasonable value
        ship_type       => 'excavator',
    );
    
    if (scalar @avaliable_excavators) {
        # Get spaceport
        my $spaceport_object = $self->build_object($spaceport);
        # Get unprobed stars
        my @planets = $self->farthest_known_planets($planet_stats->{x},$planet_stats->{y},scalar(@avaliable_excavators));
        
        foreach my $body (@planets) {
            my $excavator = pop(@avaliable_excavators);
            if (defined $excavator) {
                
                # Send excavator to body
                my $response = $self->request(
                    object  => $spaceport_object,
                    method  => 'send_ship',
                    params  => [ $excavator,{ "body_id" => $body } ],
                );
            }
        }
    }
}

sub farthest_known_planets {
    my ($self,$x,$y,$limit) = @_;
    
    $limit //= 1;
    
    my @planets;
    
    STARS:
    foreach my $star ($self->stars_by_distance($x,$y,1)) {
        # Check if star known to be unprobed
        next STARS
            unless $self->is_probed_star($star->{id});
        
        # Get star info
        my $star_info = $self->get_star($star->{id});
        
        # Loop all bodies
        BODIES:
        foreach my $body (@{$star_info->{bodies}}) {
            next BODIES
                if defined $body->{empire};
            next BODIES
                unless defined $body->{type} eq 'habitable planet';
            
            # TODO: Check if excavator has been sent to this body is the last 30 days
            push (@planets,$body->{id});
        }
        
        last STARS
            if scalar(@planets) >= $limit;
    }
    
    return @planets;
}

1;