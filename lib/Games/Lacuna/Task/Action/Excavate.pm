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
    default         => -4,
);

has 'min_distance' => (
    isa             => 'Int',
    is              => 'rw',
    documentation   => 'Min solar system distance',
    default         => 400,
);

use Try::Tiny;

sub description {
    return q[This task automates building and dispatching of excavators];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $timestamp = time();
    my $max_age = time() - ( 60 * 60 * 24 * 31 ); # 31 days
    
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
    
    $self->search_stars_callback(
        sub {
            my ($star_data) = @_;
            
            return 1
                unless scalar @{$star_data->{bodies}};
            
            # Loop all bodies
            BODIES:
            foreach my $body (@{$star_data->{bodies}}) {
                my $body_id = $body->{id};
                
                # Only excavate habitable planets and gas giants
                next BODIES
                    unless $body->{type} eq 'habitable planet' || $body->{type} eq 'gas giant';
                
                # Do not excavate body that has been excavated in past 30 days
                next BODIES
                    if defined $body->{last_excavated}
                    && $body->{last_excavated} >= $max_age;
                
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
                        
                        $self->set_body_excavated($body_id,$timestamp);
                    } catch {
                        my $error = $_;
                        if (blessed($error)
                            && $error->isa('LacunaRPCException')) {
                            given ($error->code) {
                                # Already excavated
                                when (1010) {
                                    $self->set_body_excavated($body_id,$timestamp);
                                    $self->log('debug',"Could not send excavator to %s since it was excavated in the last 30 days",$body->{name});
                                }
                                default {
                                    $error->rethrow();
                                }
                            }
                            push(@avaliable_excavators,$excavator);
                        } else {
                            $self->abort($error);
                        }
                    };
                }
                
                return 0
                    if scalar(@avaliable_excavators) == 0;
            }
            
            return 0
                if scalar(@avaliable_excavators) == 0;
            
            return 1;
        },
        x           => $planet_stats->{x},
        y           => $planet_stats->{y},
        probed      => 1,
        distance    => 1,
        min_distance=> $self->min_distance,
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;