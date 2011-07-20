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
    default         => -5,
);

use Try::Tiny;

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
        unless defined $spaceport;
    return
        unless defined $archaeology_ministry;
    return
        unless $archaeology_ministry->{level} == 15;
    
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
    
    # Get excavator cache
    my $excavate_cache_key = 'excavate/'.$planet_stats->{id};
    my $excavate_cache = $self->lookup_cache($excavate_cache_key) || {};
    
    $self->log('debug','%i excavators available at %s',(scalar @avaliable_excavators),$planet_stats->{name});
    
    # Get probed stars
    STARS:
    foreach my $star ($self->stars_by_distance($planet_stats->{x},$planet_stats->{y},1)) {
        # Check if star known to be unprobed
        next STARS
            unless $self->is_probed_star($star->{id});
        
        # Get star info
        my $star_info = $self->get_star($star->{id});
        
        sleep 1;
        
        # Loop all bodies
        foreach my $body (@{$star_info->{bodies}}) {
            # Do not excavate habited solar system as excavators will be shot down
            next STARS
                if defined $body->{empire} && $body->{type} eq 'habitable planet';
        }

        # Loop all bodies again
        BODIES:
        foreach my $body (@{$star_info->{bodies}}) {
            # Only excavate habitable planets
            next BODIES
                unless $body->{type} eq 'habitable planet';

            # Do not excavate body that has been excavated in past 30 days
            next BODIES
                if defined $excavate_cache->{$body->{id}}
                && $excavate_cache->{$body->{id}} >= $max_age;
            
            my $excavator = pop(@avaliable_excavators);
            
            if (defined $excavator) {
                
                try {
                    # Send excavator to body
                    my $response = $self->request(
                        object  => $spaceport_object,
                        method  => 'send_ship',
                        params  => [ $excavator,{ "body_id" => $body->{id} } ],
                    );
                    
                    $self->log('notice',"Sending excavator from %s to %s",$planet_stats->{name},$body->{name});
                } catch {
                    my $error = $_;
                    if (blessed($error)
                        && $error->isa('LacunaRPCException')) {
                        if ($error->code == 1010) {
                            $excavate_cache->{$body} = $timestamp;
                            $self->log('debug',"Could not excavate %s since it was excavated in the last 30 days",$body->{name});
                            push(@avaliable_excavators,$excavator);
                        } else {
                            $error->rethrow();
                        }    
                    } else {
                        die($error);
                    }
                };

                $excavate_cache->{$body} = $timestamp;
            }

            last STARS
                if scalar(@avaliable_excavators) == 0;
        }
        last STARS
            if scalar(@avaliable_excavators) == 0;
    }
    
    # Write to local cache
    $self->write_cache(
        key     => $excavate_cache_key,
        value   => $excavate_cache,
        max_age => (60*60*24*30*6), # Cache for 6 months
    );
}

1;
