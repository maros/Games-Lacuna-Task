package Games::Lacuna::Task::Role::Ships;

use 5.010;
use Moose::Role;

sub ships {
    my ($self,%params) = @_;
    
    my $planet_stats = $params{planet};
    my $type = lc($params{type});
    my $name_prefix = $params{name_prefix};
    my $quantity = $params{quantity} // 1;
    my $travelling = $params{travelling} // 0;
    
    return
        unless $type;
    
    # Get space port
    my @spaceports = $self->find_building($planet_stats->{id},'SpacePort');
    # Get shipyard
    my @shipyards = $self->find_building($planet_stats->{id},'Shipyard');
    
    return
        unless scalar @spaceports;
    
    my $spaceport_object = $self->build_object($spaceports[0]);
    
    # Get all available ships
    my $ships_data = $self->paged_request(
        object  => $spaceport_object,
        method  => 'view_all_ships',
        total   => 'number_of_ships',
        data    => 'ships',
    );
    
    my @known_ships;
    my $new_building = 0;
    my @avaliable_ships;
    my $building_ships = 0;
    my $travelling_ships = 0;
    my $max_build_quantity = $quantity;
    
    # Quantity is defined as free-spaceport slots
    if ($quantity < 0) {
        my $max_ship_count = 0;
        foreach my $spaceport (@spaceports) {
            $max_ship_count += $spaceport->{level} * 2;
        }
        $max_build_quantity = $max_ship_count - $ships_data->{number_of_ships} + $quantity;
    }
    
    # Find all avaliable and buildings ships
    SHIPS:
    foreach my $ship (@{$ships_data->{ships}}) {
        push(@known_ships,$ship->{id});
        
        next SHIPS
            unless $ship->{type} eq $type;
        next SHIPS
            if defined $name_prefix && $ship->{name} !~ m/^$name_prefix/;
            
        if ($ship->{task} eq 'Docked') {
            push(@avaliable_ships,$ship->{id});
        } elsif ($ship->{task} eq 'Building') {
            $building_ships ++;
        } elsif ($ship->{task} eq 'Travelling' && $travelling) {
            $travelling_ships ++;
        }
        last SHIPS
            if $quantity > 0 && scalar(@avaliable_ships) == $quantity;
    }
    
    my $total_ships = scalar(@avaliable_ships) + $building_ships + $travelling_ships;
    
    # We have to build new probes
    if (($quantity < 0 || $total_ships < $quantity)
        && scalar @shipyards
        && $max_build_quantity > 0 ) {
        
        # Loop all shipyards
        SHIPYARDS:
        foreach my $shipyard (@shipyards) {
            my $shipyard_object = $self->build_object($shipyard);
            
            # Repeat until we have enough probes
            SHIPYARD_QUEUE:
            while ($new_building < $max_build_quantity) {
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
                
                $self->log('notice',"Building %s on %s",$type,$planet_stats->{name});
                
                # Build ship
                $self->request(
                    object  => $shipyard_object,
                    method  => 'build_ship',
                    params  => [lc($type)],
                );
                
                $max_build_quantity --;
                
                $new_building ++;
                
                $total_ships ++;
            }
        }
    }
    
    # Rename new ships
    if ($new_building > 0
        && defined $name_prefix) {
            
        # Get all available ships
        my $ships_data = $self->paged_request(
            object  => $spaceport_object,
            method  => 'view_all_ships',
            total   => 'number_of_ships',
            data    => 'ships',
        );
        
        NEW_SHIPS:
        foreach my $ship (@{$ships_data->{ships}}) {
            next NEW_SHIPS
                if $ship->{id} ~~ \@known_ships;
            
            my $name = $name_prefix .': '.$ship->{name};
            
            $self->log('notice',"Renaming new ship to %s on %s",$name,$planet_stats->{name});
            
            # Rename ship
            $self->request(
                object  => $spaceport_object,
                method  => 'name_ship',
                params  => [$ship->{id},$name],
            );
        }
    }
    
    return @avaliable_ships;
}

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Role::Ships - Helper methods for fetching and building ships

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
        ships_needed    => 3, # get three
        ship_type       => 'scow',
    );

Tries to fetch the given number of available ships. If there are not enough 
ships available then the required number of ships are built.

=cut

no Moose::Role;
1;