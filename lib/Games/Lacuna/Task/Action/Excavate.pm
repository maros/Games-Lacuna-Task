package Games::Lacuna::Task::Action::Excavate;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars
    Games::Lacuna::Task::Role::Ships);

has 'excavator_count' => (
    isa             => 'Int',
    is              => 'rw',
    documentation   => 'Defines how many excavators should be dispatched simulaneously',
    default         => 2,
);

sub description {
    return q[This task automates building and dispatching of excavators];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $timestamp = DateTime->now->set_time_zone('UTC');
    my $max_age = $timestamp->subtract( days => 30 );
    
    # Get archaeology ministry
    my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
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
        ships_needed    => $self->excavator_count,
        ship_type       => 'excavator',
    );
    
    # Check if we have available excavators
    return
        unless (scalar @avaliable_excavators);
    
    # Get spaceport
    my $spaceport_object = $self->build_object($spaceport);
    
    # Get excavator cache
    my $excavate_cache_key = 'excavate/'.$planet_stats->{id};
    my $excavate_cache = $self->lookup_cache($excavate_cache_key) || {};
    
    # Get unprobed stars
    STARS:
    foreach my $star ($self->stars_by_distance($planet_stats->{x},$planet_stats->{y},1)) {
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
            next BODIES
                if defined $excavate_cache->{$body->{id}}
                && $excavate_cache->{$body->{id}} >= $max_age;
            
            my $excavator = pop(@avaliable_excavators);
            
            if (defined $excavator) {
                
                # Send excavator to body
                my $response = $self->request(
                    object  => $spaceport_object,
                    method  => 'send_ship',
                    params  => [ $excavator,{ "body_id" => $body } ],
                );
                
                $excavate_cache->{$body} = $timestamp;
            }
        }
        last STARS
            if scalar(@avaliable_excavators) == 0;
    }
    
    # Write to local cache
    $self->write_cache(
        key     => $excavate_cache_key,
        value   => $excavate_cache,
        max_age => (60*60*24*30), # Cache for 30 days
    );
}

1;
