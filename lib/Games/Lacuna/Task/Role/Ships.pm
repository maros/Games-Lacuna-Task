package Games::Lacuna::Task::Role::Ships;

use 5.010;
use Moose::Role;

use List::Util qw(min sum max first);
use Games::Lacuna::Task::Utils qw(parse_ship_type);

sub push_ships {
    my ($self,$form_id,$to_id,$ships) = @_;
    
    my $trade_object = $self->get_building_object($form_id,'Trade');
    my $spaceport_object = $self->get_building_object($form_id,'SpacePort');
    
    return 0
        unless $trade_object && $spaceport_object;
    
    my $trade_cargo = scalar(@{$ships}) * $Games::Lacuna::Task::Constants::CARGO{ship};
    
    my @cargo;
    my $send_with_ship_id;
    my $send_ship_stay = 0;
    
    foreach my $ship (sort { $b->{speed} <=> $a->{speed} }  @{$ships}) {
        if ($ship->{type} ~~ [qw(galleon hulk cargo freighter hulk smuggler)]
            && $ship->{hold_size} >= ($trade_cargo - $Games::Lacuna::Task::Constants::CARGO{ship})
            && ! defined $send_with_ship_id) {
            $send_with_ship_id =  $ship->{id};
            $send_ship_stay = 1;
        } else {
            push (@cargo,{
                "type"      => "ship",
                "ship_id"   => $ship->{id},
            });
        }
    }
    
    # Get trade ship
    $send_with_ship_id ||= $self->trade_ships($form_id,$trade_cargo);
    
    return
        unless $send_with_ship_id;

    # Add minimum cargo
    push(@cargo,{
        "type"      => "water",
        "quantity"  => 1,
    }) unless scalar(@cargo);

    # Rename ships
    foreach my $ship (@{$ships}) {
        my $name = $ship->{name};
        
        # Replace one exclamation mark
        $name =~ s/!//;
        
        if ($name ne $ship->{name}) {
            $self->request(
                object  => $spaceport_object,
                method  => 'name_ship',
                params  => [$ship->{id},$name],
            );
        }
    }
    
    my $response = $self->request(
        object  => $trade_object,
        method  => 'push_items',
        params  => [ $to_id, \@cargo, { 
            ship_id => $send_with_ship_id,
            stay    => $send_ship_stay,
        } ]
    );
    

    return scalar(@{$ships});
}

sub trade_ships {
    my ($self,$body_id,$cargo) = @_;
    
    my $trade = $self->find_building($body_id,'Trade');
    return 
        unless defined $trade;
    my $trade_object = $self->build_object($trade);
    
    my $trade_ships = $self->request(
        object  => $trade_object,
        method  => 'get_trade_ships',
    )->{ships};
    
    TRADE_SHIP:
    foreach my $ship (sort { $b->{speed} <=> $a->{speed} } @{$trade_ships}) {
        next TRADE_SHIP
            if $ship->{hold_size} < $cargo;
        next TRADE_SHIP
            if $ship->{name} =~ m/\!/;
        return $ship->{id};
    }
    
    return;
}

sub ships {
    my ($self,%params) = @_;
    
    my $planet_stats = $params{planet};
    my $type = parse_ship_type($params{type});
    my $name_prefix = $params{name_prefix};
    my $quantity = $params{quantity} // 1;
    my $travelling = $params{travelling} // 0;
    my $build = $params{build} // 1;
    
    return
        unless $type && defined $planet_stats;
    
    # Get space port
    my @spaceports = $self->find_building($planet_stats->{id},'SpacePort');
    return
        unless scalar @spaceports;
    
    my $spaceport_object = $self->build_object($spaceports[0]);
    
    # Get all available ships
    my $ships_data = $self->request(
        object  => $spaceport_object,
        method  => 'view_all_ships',
        params  => [ { no_paging => 1 } ],
    );
    
    # Initialize vars
    my @known_ships;
    my @avaliable_ships;
    my $building_ships = 0;
    my $travelling_ships = 0;
    
    # Find all avaliable and buildings ships
    SHIPS:
    foreach my $ship (@{$ships_data->{ships}}) {
        push(@known_ships,$ship->{id});
        
        next SHIPS
            unless $ship->{type} eq $type;
        
        # Check ship prefix and flags
        if (defined $name_prefix) {
            next SHIPS
                 unless $ship->{name} =~ m/^$name_prefix/i;
        } else {
            next SHIPS
                if $ship->{name} =~ m/\!/; # Indicates reserved ship
        }
        
        # Get ship activity
        if ($ship->{task} eq 'Docked') {
            push(@avaliable_ships,$ship->{id});
        } elsif ($ship->{task} eq 'Building') {
            $building_ships ++;
        } elsif ($ship->{task} eq 'Travelling' && $travelling) {
            $travelling_ships ++;
        }
        
        # Check if we have enough ships
        return @avaliable_ships
            if defined $quantity 
            && $quantity > 0 
            && scalar(@avaliable_ships) >= $quantity;
    }
    
    return @avaliable_ships
        unless $build;
    
    # Check if we have a shipyard
    my @shipyards = $self->find_building($planet_stats->{id},'Shipyard');
    return @avaliable_ships
        unless (scalar @shipyards);
    
    # Calc max spaceport capacity
    my $max_ships_possible = sum map { $_->{level} * 2 } @spaceports;
    
    my $max_build_quantity;
    
    # Quantity is defined as free-spaceport slots
    if ($quantity < 0) {
        $max_build_quantity = max($max_ships_possible - $ships_data->{number_of_ships} + $quantity,0);
    # Quantity is defined as number of ships
    } else {
        $max_build_quantity = min($max_ships_possible - $ships_data->{number_of_ships},$quantity);
        $max_build_quantity -= $building_ships;
        $max_build_quantity = max($max_build_quantity,0);
    }
    
    # Check if we can build new ships
    return @avaliable_ships
        unless ($max_build_quantity > 0);
    
    # Calc current ships
    my $total_ships = scalar(@avaliable_ships) + $building_ships + $travelling_ships;
    
    # We have to build new ships
    my %available_shipyards;
    my $new_building = 0;
    my $total_queue_size = 0;
    my $total_max_queue_size = 0;
    
    # Loop all shipyards to get levels ans workload
    SHIPYARDS:
    foreach my $shipyard (@shipyards) {
        my $shipyard_id = $shipyard->{id};
        my $shipyard_object = $self->build_object($shipyard);
        
        # Get build queue
        my $shipyard_queue_data = $self->request(
            object  => $shipyard_object,
            method  => 'view_build_queue',
            params  => [1],
        );
        
        my $shipyard_queue_size = $shipyard_queue_data->{number_of_ships_building} // 0;
        $total_max_queue_size += $shipyard->{level};
        $total_queue_size += $shipyard_queue_size;
        
        # Check available build slots
        next SHIPYARDS
            if $shipyard->{level} <= $shipyard_queue_size;
            
        $available_shipyards{$shipyard_id} = {
            id                  => $shipyard_id,
            object              => $shipyard_object,
            level               => $shipyard->{level},
            seconds_remaining   => ($shipyard_queue_data->{building}{work}{seconds_remaining} // 0),
            available           => ($shipyard->{level} - $shipyard_queue_size), 
        };
    }
    
    # Check if shipyards are available
    return @avaliable_ships
        unless scalar keys %available_shipyards;
    
    # Check max build queue size
    $max_build_quantity = min($total_max_queue_size-$total_queue_size,$max_build_quantity);
    
    # Check if we still can build ships
    return @avaliable_ships
        if $max_build_quantity <= 0;
    
    
    # Repeat until we have enough ships
    BUILD_QUEUE:
    while ($new_building < $max_build_quantity) {
        
        my $shipyard = 
            first { $_->{available} > 0 }
            sort { $a->{seconds_remaining} <=> $b->{seconds_remaining} } 
            values %available_shipyards;
        
        last BUILD_QUEUE
            unless defined $shipyard;
        
        # Get build quantity
        my $build_per_shipyard = int($max_build_quantity / scalar (keys %available_shipyards) / 2) || 1;
        my $build_quantity = min($shipyard->{available},$max_build_quantity,$build_per_shipyard);
        
        eval {
            # Build ship
            my $ship_building = $self->request(
                object  => $shipyard->{object},
                method  => 'build_ship',
                params  => [$type,$build_quantity],
            );
            
            $shipyard->{seconds_remaining} = $ship_building->{building}{work}{seconds_remaining};
            
            $self->log('notice',"Building %i %s(s) on %s at shipyard level %i",$build_quantity,$type,$planet_stats->{name},$shipyard->{level});
            
            # Remove shipyard slot
            $shipyard->{available} -= $build_quantity;
            
            # Remove from available shipyards
            delete $available_shipyards{$shipyard->{id}}
                if $shipyard->{available} <= 0;
        };
        if ($@) {
            $self->log('warn','Could not build %s: %s',$type,$@);
            last BUILD_QUEUE;
        }
        
        $new_building += $build_quantity;
        $total_ships += $build_quantity;
    }
    
    # Rename new ships
    if ($new_building > 0
        && defined $name_prefix) {
            
        # Get all available ships
        my $ships_data = $self->request(
            object  => $spaceport_object,
            method  => 'view_all_ships',
            params  => [ { no_paging => 1 } ],
        );
        
        NEW_SHIPS:
        foreach my $ship (@{$ships_data->{ships}}) {
            next NEW_SHIPS
                if $ship->{id} ~~ \@known_ships;
            next NEW_SHIPS
                unless $ship->{type} eq $type;
            
            my $name = $name_prefix .': '.$ship->{name}.'!';
            
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

no Moose::Role;
1;

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

The following arguments are accepted

=over

=item * planet

Planet data has [Required]

=item * ships_needed

Number of required ships. If ships_needed is a negative number it will return
all matching ships and build as many new ships as possible while keeping 
ships_needed * -1 space port slots free [Required]

=item  * ship_type

Ship type [Required]

=item * travelling

If true will not build new ships if there are matchig ships currently 
travelling

=item * name_prefix

Will only return ships with the given prefix in their names. Newly built ships
will be renamed to add the prefix.

=back

=head2 trade_ships

 my $trade_ship_id = $self->trade_ships($body_id,$cargo);

Returns a ship that can transport the required quantity of cargo

=head2 push_ships

 $self->push_ships($from_body_id,$to_body_id,\@ships);

Pushes the selected ships from one body to another

=cut
