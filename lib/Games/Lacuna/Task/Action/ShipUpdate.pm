package Games::Lacuna::Task::Action::ShipUpdate;

use 5.010;

use Moose;
# -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun
    Games::Lacuna::Task::Role::Ships);

our @ATTRIBUTES = qw(hold_size combat speed stealth);

use List::Util qw(min max);
use Games::Lacuna::Task::Utils qw(normalize_name);

has 'handle_ships' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    documentation   => "List of ships which should be handled [Multiple]",
    default         => sub {
        return [qw(barge cargo_ship dory fighter freighter galleon hulk observatory_seeker scow security_ministry_seeker smuggler_ship snark spaceport_seeker sweeper)];
    },
);

has 'best_ships' => (
    is              => 'rw',
    isa             => 'HashRef',
    traits          => ['NoGetopt','Hash'],
    lazy_build      => 1,
    handles         => {
        available_best_ships  => 'count',
    },
);

has 'threshold' => (
    is              => 'rw',
    isa             => 'Int',
    required        => 1,
    default         => 20,
    documentation   => "Threshold for ship attributes [Default: 20%]",
);

sub description {
    return q[Keep fleet up to date by building new ships and scuttling old ones];
}

sub run {
    my ($self) = @_;
    
    unless ($self->available_best_ships) {
        $self->log('notice','No sphipyard slots available. Cannot proceed');
        return;
    }
    
    foreach my $planet_stats ($self->get_planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        $self->process_planet($planet_stats);
    }
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get space port
    my $spaceport_object = $self->get_building_object($planet_stats->{id},'SpacePort');
    
    return 
        unless $spaceport_object;
    
    # Get all available ships
    my $ships_data = $self->request(
        object  => $spaceport_object,
        method  => 'view_all_ships',
        params  => [ { no_paging => 1 } ],
    );
    
    my $old_ships = {};
    my $threshold = $self->threshold / 100 + 1;
    
    foreach my $ship (@{$ships_data->{ships}}) {
        my $ship_type = $ship->{type};
        $ship_type =~ s/\d$//;
        
        next
            unless $ship_type ~~ $self->handle_ships;
        next
            unless defined $self->best_ships->{$ship_type};
        
        my $best_ship = $self->best_ships->{$ship_type};
        
        my $ship_is_ok = 1;
        
        foreach my $attribute (@ATTRIBUTES) {
            if ($best_ship->{$attribute} / $threshold > $ship->{$attribute}) {
                $self->log('debug','Ship %s on %s is outdated (%s %i vs. %i)',$ship->{name},$planet_stats->{name},$attribute,$ship->{$attribute},$best_ship->{$attribute});
                $ship_is_ok = 0;
                last;
            }
        }
        
        next
            if $ship_is_ok;
        
        $old_ships->{$ship_type} ||= [];
        
        push (@{$old_ships->{$ship_type}},$ship);
    }
    
    foreach my $ship_type (sort { scalar @{$old_ships->{$b}} <=> scalar @{$old_ships->{$a}} } keys %{$old_ships}) {
        my $old_ships = $old_ships->{$ship_type};
        my $best_ships = $self->best_ships->{$ship_type};
        
        my $new_building = $self->build_ships(
            planet              => $self->my_body_status($best_ships->{planet}{planet}),
            quantity            => scalar(@{$old_ships}),
            type                => $ship_type,
            spaceports_slots    => $best_ships->{spaceport_slots},
            shipyard_slots      => $best_ships->{shipyard_slots},
            shipyards           => $best_ships->{shipyards},
        );
        
        warn $new_building;
        
        for (1..$new_building) {
            my $old_ship = pop(@{$old_ships});
            
            $self->request(
                object  => $spaceport_object,
                method  => 'name_ship',
                params  => [$old_ship->{id},$old_ship->{name}.' Scuttle!'],
            );
        }
    }
}

sub _build_best_ships {
    my ($self) = @_;
    
    $self->log('info',"Get best build planet for each ship type");
    
    my $best_ships = {};
    foreach my $planet_stats ($self->get_planets) {
        my $buildable_ships = $self->get_buildable_ships($planet_stats);
        
        BUILDABLE_SHIPS:
        while (my ($type,$data) = each %{$buildable_ships}) {
            $data->{planet} = $planet_stats->{id};
            $best_ships->{$type} ||= $data;
            
            foreach my $attribute (@ATTRIBUTES) {
                if ($best_ships->{$type}{$attribute} < $data->{$attribute}) {
                    
                    $best_ships->{$type} = $data;
                    next BUILDABLE_SHIPS;
                }
            }
        }
    }
    
    my $build_planets = {};
    foreach my $best_ship (keys %{$best_ships}) {
        my $planet_id = $best_ships->{$best_ship}{planet};
        
        unless (defined $build_planets->{$planet_id}) {
            my ($available_shipyard_slots,$available_shipyards) = $self->shipyard_slots($planet_id);
            my ($available_spaceport_slots) = $self->spaceport_slots($planet_id);
            
            # Get all available ships
            my $ships_data = $self->request(
                object  => $self->get_building_object($planet_id,'SpacePort'),
                method  => 'view_all_ships',
                params  => [ { no_paging => 1 } ],
            );
            
            $build_planets->{$planet_id} = {
                planet          => $planet_id,
                shipyard_slots  => max($available_shipyard_slots,0),
                spaceport_slots => max($available_spaceport_slots,0),
                shipyards       => $available_shipyards,
            };
        }
        
        $best_ships->{$best_ship}{planet} = $build_planets->{$planet_id};
    }
    
    foreach my $best_ship (keys %{$best_ships}) {
        delete $best_ships->{$best_ship}
            if $best_ships->{$best_ship}{planet}{shipyard_slots} <= 0;
        delete $best_ships->{$best_ship}
            if $best_ships->{$best_ship}{planet}{spaceport_slots} <= 0;
    }
    
    return $best_ships;
}

sub get_buildable_ships {
    my ($self,$planet_stats) = @_;
    
    my $shipyard = $self->find_building($planet_stats->{id},'Shipyard');
    
    return
        unless $shipyard;
    
    my $shipyard_object = $self->build_object($shipyard);
    
    my $ship_buildable = $self->request(
        object  => $shipyard_object,
        method  => 'get_buildable',
    );
    
    my $ships = {};
    while (my ($type,$data) = each %{$ship_buildable->{buildable}}) {
        my $ship_type = $type;
        $ship_type =~ s/\d$//;
        
        next
            unless $ship_type ~~ $self->handle_ships;
        next
            if $data->{can} == 0 
            && $data->{reason}[1] !~ /You can only have \d+ ships in the queue at this shipyard/;
        next
            if defined $ships->{$ship_type}
            && grep { $data->{attributes}{$_} < $ships->{$ship_type}{$_} } @ATTRIBUTES;
        
        $ships->{$ship_type} = {
            (map { $_ => $data->{attributes}{$_} } @ATTRIBUTES),
            type    => $type,
        };
    }
    
    return $ships;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;