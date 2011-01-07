package Games::Lacuna::Task::Role::Ships;

use 5.010;
use Moose::Role;

sub ships {
    my ($self,%params) = @_;
    
    my $planet_stats = $params{planet};
    my $ship_type = $params{ship_type};
    my $ships_needed = $params{ships_needed} // 1;
    
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
    
    # Find all avaliable and buildings ships
    SHIPS:
    foreach my $ship (@{$ships_data->{ships}}) {
        next SHIPS
            unless $ship->{type} eq $ship_type;
        if ($ship->{task} eq 'Docked') {
            push(@avaliable_ships,$ship->{id});
        } elsif ($ship->{task} eq 'Building') {
            $building_ships ++;
        }
        last SHIPS
            if scalar(@avaliable_ships) == $ships_needed;
    }
    
    my $total_ships = scalar(@avaliable_ships) + $building_ships;
    
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

no Moose::Role;
1;