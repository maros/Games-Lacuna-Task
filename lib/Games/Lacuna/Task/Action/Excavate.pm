package Games::Lacuna::Task::Action::Excavate;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars
    Games::Lacuna::Task::Role::Ships
    Games::Lacuna::Task::Role::PlanetRun
    Games::Lacuna::Task::Role::RPCLimit);

has 'excavator_count' => (
    isa             => 'Int',
    is              => 'rw',
    documentation   => 'Number of excavators that should be dispatched simulaneously',
    default         => -5,
);

has 'min_distance' => (
    isa             => 'Int',
    is              => 'rw',
    documentation   => 'Min solar system distance',
    default         => 500,
);

use Try::Tiny;

sub description {
    return q[This task automates building and dispatching of excavators];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $now = DateTime->now->set_time_zone('UTC');
    my $max_age = $now->subtract( days => 31 )->epoch();
    my $timestamp = $now->epoch();
    
    # Get archaeology ministry
    my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'Space Port');
    
    return 
        unless defined $spaceport;
    return
        unless defined $archaeology_ministry;
    return
        unless $archaeology_ministry->{level} >= 15;
        
    # Get spaceport
    my $spaceport_object = $self->build_object($spaceport);
    
    # Get available excavators
    my @avaliable_excavators = $self->ships(
        planet          => $planet_stats,
        quantity        => $self->excavator_count,
        travelling      => 1,
        type            => 'excavator',
    );
    
    # Check if we have available excavators
    return
        unless (scalar @avaliable_excavators);
    
    $self->log('debug','%i excavators available at %s',(scalar @avaliable_excavators),$planet_stats->{name});
    
    my $callback = sub {
        my ($star,$distance) = @_;
        return 0
            if $distance < $self->min_distance;
        return 1;
    };
    
    # Get probed stars
    STARS:
    foreach my $star ($self->stars_by_distance($planet_stats->{x},$planet_stats->{y},$callback)) {
        # Get star info
        my $star_data = $self->get_star($star->{id});
        
        # Check star bodies
        next STARS
            unless defined $star_data->{bodies}
            && scalar @{$star_data->{bodies}} > 0;;
        
        # Loop all bodies
        foreach my $body (@{$star_data->{bodies}}) {
            
            # Do not excavate bodies in inhabited solar system to avoid SAWs
            next STARS
                if defined $body->{empire} 
                && $body->{type} eq 'habitable planet'
                && $body->{empire}{alignment} =~ /^hostile/;
        }
        
        # Get excavator cache
        my $excavate_cache_key = 'excavate/'.$star->{id};
        my $excavate_cache = $self->lookup_cache($excavate_cache_key) || {};
        
        # Loop all bodies again
        BODIES:
        foreach my $body (@{$star_data->{bodies}}) {
            my $body_id = $body->{id};
            
            # Only excavate habitable planets
            next BODIES
                unless $body->{type} eq 'habitable planet';
            
            #  Do not excavate inhabited body
            next BODIES
                if defined $body->{empire};
            
            # Do not excavate body that has been excavated in past 30 days
            next BODIES
                if defined $excavate_cache->{$body_id}
                && $excavate_cache->{$body_id} >= $max_age;
            
            my $excavator = pop(@avaliable_excavators);
            
            if (defined $excavator) {
                
                try {
                    $self->log('notice',"Sending excavator from %s to %s",$planet_stats->{name},$body->{name});
                    
                    # Send excavator to body
                    my $response = $self->request(
                        object  => $spaceport_object,
                        method  => 'send_ship',
                        params  => [ $excavator,{ "body_id" => $body_id } ],
                    );
                    
                    $excavate_cache->{$body_id} = $timestamp;
                } catch {
                    my $error = $_;
                    if (blessed($error)
                        && $error->isa('LacunaRPCException')) {
                        if ($error->code == 1010) {
                            $excavate_cache->{$body_id} = $timestamp;
                            $self->log('debug',"Could not send excavator to %s since it was excavated in the last 30 days",$body->{name});
                            push(@avaliable_excavators,$excavator);
                        } else {
                            $error->rethrow();
                        }    
                    } else {
                        die($error);
                    }
                };
            }
            
            last BODIES
                if scalar(@avaliable_excavators) == 0;
        }
        
        # Write to local cache
        $self->write_cache(
            key     => $excavate_cache_key,
            value   => $excavate_cache,
            max_age => (60*60*24*30), # Cache for 1 month
        );
        
        last STARS
            if scalar(@avaliable_excavators) == 0;
    }
    

}

1;
