package Games::Lacuna::Task::Action::ShipUpdate;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;
no if $] >= 5.017004, warnings => qw(experimental::smartmatch);

use Moose;
# -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun
    Games::Lacuna::Task::Role::Ships
    Games::Lacuna::Task::Role::BestShips);

use List::Util qw(min max);
use Games::Lacuna::Task::Utils qw(normalize_name);

has 'handle_ships' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    documentation   => "List of ships which should be handled [Multiple]",
    default         => sub {
        return [qw(barge 
            cargo_ship 
            dory 
            fighter 
            freighter 
            galleon 
            hulk 
            hulk_fast
            hulk_huge
            observatory_seeker 
            scow
            scow_fast
            scow_large
            scow_mega
            security_ministry_seeker 
            smuggler_ship 
            snark 
            spaceport_seeker 
            sweeper
            )];
    },
);

has 'threshold' => (
    is              => 'rw',
    isa             => 'Int',
    required        => 1,
    default         => 15,
    documentation   => "Threshold for ship attributes [Default: 15%]",
);

sub description {
    return q[Keep fleet up to date by building new ships and scuttling old ones. Best used in conjunction with ship_dispatch];
}

sub run {
    my ($self) = @_;
    
    unless ($self->available_best_ships) {
        $self->log('notice','No sphipyard slots available. Cannot proceed');
        return;
    }
    
    foreach my $planet_stats ($self->get_planets) {
        last 
            unless $self->has_best_planet;
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
    
    # Loop all shios
    SHIPS:
    foreach my $ship (@{$ships_data->{ships}}) {
        my $ship_type = $ship->{type};
        $ship_type =~ s/\d$//;
        
        # Filter ships by name, type and task
        next
            if $ship->{name} =~ m/\b (scuttle|ignore|!) \b/ix;
        next
            if $ship->{task} ~~ ['Waiting On Trade','Building'];
        next
            unless $ship_type ~~ $self->handle_ships;
        next
            unless defined $self->best_ships->{$ship_type};
        
        my $best_ship = $self->get_best_ship($ship_type);
        
        my $ship_is_ok = 1;
        
        foreach my $attribute (@Games::Lacuna::Task::Constants::SHIP_ATTRIBUTES) {
            if ($ship->{$attribute} > $best_ship->{$attribute}) {
                next SHIPS;
            }
            if ($ship->{$attribute} < ($best_ship->{$attribute} / $threshold)) {
                $ship_is_ok = 0;
            }
        }
        
        next
            if $ship_is_ok;
        
        $self->log('debug','Ship %s on %s is outdated',$ship->{name},$planet_stats->{name});
        
        $old_ships->{$ship_type} ||= [];
        push (@{$old_ships->{$ship_type}},$ship);
    }
    foreach my $ship_type (sort { scalar @{$old_ships->{$b}} <=> scalar @{$old_ships->{$a}} } keys %{$old_ships}) {
        my $old_ships = $old_ships->{$ship_type};
        my $best_ships = $self->get_best_ship($ship_type);
        my $build_planet_id = $best_ships->{planet};
        my $build_planet_stats = $self->get_best_planet($build_planet_id);
        
        next
            if ! defined $build_planet_stats 
            || $build_planet_stats->{total_slots} <= 0;
            
        my $build_spaceport = $self->find_building($build_planet_id,'SpacePort');
        my $build_spaceport_object = $self->build_object($build_spaceport);
        
        my (@ships_mining,@ship_chain,@ships_general);
        foreach my $old_ship (@{$old_ships}) {
            if ($old_ship->{task} eq 'Mining') {
                push(@ships_mining,$old_ship); 
            } elsif ($old_ship->{task} =~ /\sChain/) {   
                push(@ship_chain,$old_ship);
            } else {
                push(@ships_general,$old_ship); 
            }
        }
        
        my @new_building = $self->build_ships(
            planet              => $self->my_body_status($build_planet_id),
            quantity            => scalar(@{$old_ships}),
            type                => $best_ships->{type},
            spaceports_slots    => $build_planet_stats->{spaceport_slots},
            shipyard_slots      => $build_planet_stats->{shipyard_slots},
            shipyards           => $build_planet_stats->{shipyards},
            name_prefix         => $planet_stats->{name},
        );
        
        my $new_building_count = scalar(@new_building);
        $build_planet_stats->{spaceport_slots} -= $new_building_count;
        $build_planet_stats->{shipyard_slots} -= $new_building_count;
        $build_planet_stats->{total_slots} -= $new_building_count;
        
        foreach my $new_ship (@new_building) {
            my $old_ship;
            if ($old_ship = pop(@ships_mining)) {
                $self->name_ship(
                    spaceport   => $build_spaceport_object,
                    ship        => $new_ship,
                    prefix      => [ $planet_stats->{name},'Mining' ],
                    name        => $new_ship->{type_human},
                );
            } elsif ($old_ship = pop(@ship_chain)) {
                $self->name_ship(
                    spaceport   => $build_spaceport_object,
                    ship        => $new_ship,
                    prefix      => [ $planet_stats->{name},'Chain' ],
                    name        => $new_ship->{type_human},
                );
            } else {
                $old_ship = pop(@ships_general);
                my $old_name = $old_ship->{name};
                my $ignore = ($old_name =~ s/!// ? 1:0);
                my ($prefix,$name); 
                if ($old_ship->{name} =~ m/^(.+):(.+)$/) {
                    $prefix = [ split(/,/,$1) ];
                    push(@{$prefix},$planet_stats->{name})
                        unless $planet_stats->{name} ~~ $prefix;
                    $name = $2;
                }
                
                $self->name_ship(
                    spaceport   => $build_spaceport_object,
                    ship        => $new_ship,
                    prefix      => $prefix,
                    ignore      => $ignore,
                    name        => $name,
                );
            }
            
            $self->name_ship(
                spaceport   => $spaceport_object,
                ship        => $old_ship,
                prefix      => 'Scuttle',
                ignore      => 1,
            );
        }
        
        #$self->check_best_planets;
    }
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::ShipUpdate - Keeps your fleet up to date by building new ships and scuttling old ones

=head1 DESCRIPTION

This task replaces outdated ships. It does so by checking the best possible 
stats for each ship type at each shipyard of your empire and comparing the 
existing ships with this figures. Outdated ships will be scuttled and 
replacements will be built.

Only works in conjunction with the ship_dispatch task

=cut