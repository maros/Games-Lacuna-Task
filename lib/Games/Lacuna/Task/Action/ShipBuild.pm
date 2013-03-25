package Games::Lacuna::Task::Action::ShipBuild;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Ships',
    'Games::Lacuna::Task::Role::BestShips',
    'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['home_planet'] };

use Games::Lacuna::Task::Utils qw(normalize_name);

has 'ship_type' => (
    is              => 'rw',
    isa             => 'Str',
    documentation   => "Ship type to build",
    required        => 1,
);

has 'count' => (
    is              => 'rw',
    isa             => 'Int',
    required        => 1,
    documentation   => "Number of ships to be build",
);

sub description {
    return q[Build the selected number of ships];
}

sub run {
    my ($self) = @_;
    
    my $planet_home = $self->home_planet_data();
    my $best_ship = $self->get_best_ship($self->ship_type);
    
    $self->abort('You cannot build a %s',$self->ship_type)
        unless $best_ship;
    
    my $build_planet_id = $best_ship->{planet};
    my $build_stats = $self->get_best_planet($build_planet_id);
    my $build_planet_stats = $self->my_body_status($build_planet_id);
    
    $self->abort('No slots available at %s',$build_planet_stats->{name})
        if ! defined $build_stats 
        ||$build_stats->{total_slots} <= 0;
            
    $self->build_ships(
        planet              => $build_planet_stats,
        quantity            => $self->count,
        type                => $best_ship->{type},
        
        spaceports_slots    => $build_stats->{spaceport_slots},
        shipyard_slots      => $build_stats->{shipyard_slots},
        shipyards           => $build_stats->{shipyards},
        name_prefix         => $planet_home->{name},
    );
}

sub handle_ships {
    my ($self) = @_;
    return $self->ship_type;  
}

sub process_planet {}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::ShipBuild - Build the selected number of ships

=head1 DESCRIPTION

This task builds new ships in the best possible shiphyard of your empire.

Only works in conjunction with the ship_dispatch task

=cut