package Games::Lacuna::Task::Role::Ships;

use 5.010;
use Moose::Role;

sub ships {
    my ($self,%params) = @_;
    
    my $planet_stats = $params{planet};
    my $ship_type = $params{ship_type};
    my $ships_needed = $params{ships_needed} // 1;
    my $ships_travelling = $params{ship_travelling} // 0;
    
    return
        unless $ship_type;
    
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'Space Port');
    # Get shipyard
    my @shipyards = $self->find_building($planet_stats->{id},'Shipyard');
    
    return
        unless $spaceport;
    
    my $spaceport_object = $self->build_object($spaceport);
    
    # Get all available ships
    my $ships_data = $self->paged_request(
        object  => $spaceport_object,
        method  => 'view_all_ships',
        total   => 'number_of_ships',
        data    => 'ships',
    );
    
    my @avaliable_ships;
    my $building_ships = 0;
    my $travelling_ships = 0;
    
    # Find all avaliable and buildings ships
    SHIPS:
    foreach my $ship (@{$ships_data->{ships}}) {
        next SHIPS
            unless $ship->{type} eq $ship_type;
        if ($ship->{task} eq 'Docked') {
            push(@avaliable_ships,$ship->{id});
        } elsif ($ship->{task} eq 'Building') {
            $building_ships ++;
        } elsif ($ship->{task} eq 'Travelling' && $ships_travelling) {
            $travelling_ships ++;
        }
        last SHIPS
            if scalar(@avaliable_ships) == $ships_needed;
    }
    
    my $total_ships = scalar(@avaliable_ships) + $building_ships + $travelling_ships;
    
    # We have to build new probes
    if ($total_ships < $ships_needed
        && scalar @shipyards) {
        
        # Loop all shipyards
        SHIPYARDS:
        foreach my $shipyard (@shipyards) {
            my $shipyard_object = $self->build_object($shipyard);
            
            # Repeat until we have enough probes
            SHIPYARD_QUEUE:
            while ($total_ships < $ships_needed) {
                my $buildable_ships = $self->request(
                    object  => $shipyard_object,
                    method  => 'get_buildable',
                );
                
                # Check available docks
                last SHIPYARDS
                    if $buildable_ships->{docks_available} == 0;
                
                # Check if probe can be built
                last SHIPYARDS
                    if $buildable_ships->{buildable}{probe}{can} == 0;
                
                $self->log('notice',"Building %s on %s",$ship_type,$planet_stats->{name});
                
                # Build ship
                $self->request(
                    object  => $shipyard_object,
                    method  => 'build_ship',
                    params  => [$ship_type],
                );
                
                $building_ships++;
                
                $total_ships = scalar(@avaliable_ships) + $building_ships;
            }
        }
    }
    
    return @avaliable_ships;
}

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Role::Ships - Ship helper methods

=head1 SYNOPSIS

    package Games::Lacuna::Task::Action::MyTask;
    use Moose;
    extends qw(Games::Lacuna::Task::Action);
    with qw(Games::Lacuna::Task::Role::Ships);
    
=head1 DESCRIPTION

This role provides ship-related helper methods.

=head1 METHODS

=head2 ships

    my @avaliable_scows = $self->ships(
        planet          => $planet_stats,
        ships_needed    => 3, # get there
        ship_type       => 'scow',
    );

Tries to fetch the given number of available ships. If there are not enough 
ships available then the missing ships are built.

=cut

no Moose::Role;
1;