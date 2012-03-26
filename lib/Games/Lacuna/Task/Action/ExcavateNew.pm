package Games::Lacuna::Task::Action::ExcavateNew;

use 5.010;

use List::Util qw(sum);

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars
    Games::Lacuna::Task::Role::Ships
    Games::Lacuna::Task::Role::PlanetRun);

has 'min_ore' => (
    is              => 'rw',
    isa             => 'Int',
    documentation   => 'Only select bodies with mininimal ore quantities [Default 9000]',
    default         => 9000,
    required        => 1,
);

sub description {
    return q[This task automates building and dispatching of excavators];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get archaeology ministry
    my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
    
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'Space Port');
    
    return 
        unless defined $spaceport;
    return
        unless defined $archaeology_ministry;
    return
        unless $archaeology_ministry->{level} >= 11;
    
    
    # Get building objects
    my $archaeology_ministry_object = $self->build_object($archaeology_ministry);
    my $spaceport_object = $self->build_object($spaceport);
    
    my $response = $self->request(
        object  => $archaeology_ministry_object,
        method  => 'view_excavators',
    );
    
    my $max_excavators = $response->{max_excavators};
    my $possible_excavators = $max_excavators - scalar @{$response->{excavators}};
    
    # Check if we can have more excavators
    return
        if $possible_excavators <= 0;
    
    
    # Get available excavators
    my @avaliable_excavators = $self->get_ships(
        planet          => $planet_stats,
        quantity        => $possible_excavators,
        travelling      => 1,
        type            => 'excavator',
        build           => 1,
    );
    
    # Check if we have available excavators
    return
        unless (scalar @avaliable_excavators);
    
    $self->log('debug','%i excavators available at %s',(scalar @avaliable_excavators),$planet_stats->{name});
    
    $self->search_stars_callback(
        sub {
            my ($star_data) = @_;
            
            return 0
                if scalar @avaliable_excavators == 0;
            
            return 1
                unless scalar @{$star_data->{bodies}};
            
            my @available_bodies;
            # Check all bodies
            foreach my $body (@{$star_data->{bodies}}) {
                # Check if solar system is inhabited by hostile empires
                return 1
                    if defined $body->{empire}
                    && $body->{empire}{alignment} =~ m/hostile/;
                
                # Check if body is inhabited
                next
                    if defined $body->{empire};
                
                # Check if already excavated
                next
                    if defined $body->{is_excavated}
                    && $body->{is_excavated};
                
                # Check body type
                next 
                    unless ($body->{type} eq 'asteroid' || $body->{type} eq 'habitable planet');
                
                my $ore = sum values %{$body->{ore}};
                
                next
                    if $ore < $self->min_ore;
                
                push(@available_bodies,$body);
            }
            
            # We have enough possible targets
            return 1
                unless scalar @available_bodies;
            
            # Loop all available bodies
            foreach my $body (@available_bodies) {
                my $excavator = pop(@avaliable_excavators);
                
                return
                    unless defined $excavator;
                
                $self->log('notice',"Sending excavator from %s to %s",$planet_stats->{name},$body->{name});
                
                # Send excavator to body
                my $response = $self->request(
                    object  => $spaceport_object,
                    method  => 'send_ship',
                    params  => [ $excavator,{ "body_id" => $body->{id} } ],
                    catch   => [
                        [
                            1010,
                            qr/already has an excavator from your empire or one is on the way/,
                            sub {
                                $self->log('debug',"Could not send excavator to %s",$body->{name});
                                push(@avaliable_excavators,$excavator);
                                return 0;
                            }
                        ],
                    ],
                );
                
                # Set body exacavated
                $self->set_body_excavated($body->{id});
            }
            
            return 1;
        },
        x           => $planet_stats->{x},
        y           => $planet_stats->{y},
        is_known    => 1,
        distance    => 1,
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;