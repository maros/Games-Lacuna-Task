package Games::Lacuna::Task::Role::BestShips;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;

use List::Util qw(min max);

has 'best_ships' => (
    is              => 'rw',
    isa             => 'HashRef',
    traits          => ['NoGetopt','Hash'],
    lazy_build      => 1,
    handles         => {
        available_best_ships    => 'count',
        get_best_ship           => 'get',
        best_ship_types         => 'keys',
    },
);

has 'best_planets' => (
    is              => 'rw',
    isa             => 'HashRef',
    traits          => ['NoGetopt','Hash'],
    lazy_build      => 1,
    handles         => {
        get_best_planet         => 'get',
        remove_best_planet      => 'delete',
        has_best_planet         => 'count',
        best_planet_ids         => 'keys',
    },
);

before 'run' => sub {
    my ($self) = @_;
    
    foreach my $planet_id ($self->best_planet_ids) {
        $self->remove_best_planet($planet_id)
            if $self->get_best_planet($planet_id)->{total_slots} <= 0;
    }
};

sub get_buildable_ships {
    my ($self,$planet_stats) = @_;
    
    my $shipyard = $self->find_building($planet_stats->{id},'Shipyard');
    
    return
        unless defined $shipyard;
    
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
            && $data->{reason}[1] !~ m/^You can only have \d+ ships in the queue at this shipyard/i
            && $data->{reason}[1] !~ m/^You do not have \d docks available at the Spaceport/i;
        next
            if defined $ships->{$ship_type}
            && grep { $data->{attributes}{$_} < $ships->{$ship_type}{$_} } @Games::Lacuna::Task::Constants::SHIP_ATTRIBUTES;
        
        $ships->{$ship_type} = {
            (map { $_ => $data->{attributes}{$_} } @Games::Lacuna::Task::Constants::SHIP_ATTRIBUTES),
            type    => $type,
            class   => $ship_type,
        };
    }
    
    return $ships;
    # $ship_buildable->{docks_available}
}

sub _build_best_ships {
    my ($self) = @_;
    
    my $best_ships = {};
    foreach my $planet_stats ($self->get_planets) {
        $self->log('info',"Checking best ships at planet %s",$planet_stats->{name});
        my $buildable_ships = $self->get_buildable_ships($planet_stats);
        
        BUILDABLE_SHIPS:
        while (my ($type,$data) = each %{$buildable_ships}) {
            $data->{planet} = $planet_stats->{id};
            $best_ships->{$type} ||= $data;
            foreach my $attribute (@Games::Lacuna::Task::Constants::SHIP_ATTRIBUTES) {
                if ($best_ships->{$type}{$attribute} < $data->{$attribute}) {
                    
                    $best_ships->{$type} = $data;
                    next BUILDABLE_SHIPS;
                }
            }
        }
    }
    
    return $best_ships;
}

sub _build_best_planets {
    my ($self) = @_;
    
    my $best_planets = {};
    foreach my $best_ship ($self->best_ship_types) {
        my $planet_id = $self->get_best_ship($best_ship)->{planet};
        
        unless (defined $best_planets->{$planet_id}) {
            my ($available_shipyard_slots,$available_shipyards) = $self->shipyard_slots($planet_id);
            my ($available_spaceport_slots) = $self->spaceport_slots($planet_id);
            
            my $shipyard_slots = max($available_shipyard_slots,0);
            my $spaceport_slots = max($available_spaceport_slots,0);
            my $total_slots = min($shipyard_slots,$spaceport_slots);
            
            $best_planets->{$planet_id} = {
                shipyard_slots  => $shipyard_slots,
                spaceport_slots => $spaceport_slots,
                total_slots     => $total_slots,
                shipyards       => $available_shipyards,
            };
        }
        
        $self->log('info',"Best %s can be buildt at %s",$best_ship,$self->my_body_status($planet_id)->{name});
    }
    
    return $best_planets;
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

=head2 get_ships

    my @avaliable_scows = $self->get_ships(
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

 my $trade_ships = $self->trade_ships($body_id,$cargo_list);

Returns a hashref with cargo ship ids as keys and cargo lists as values.

=head2 push_ships

 $self->push_ships($from_body_id,$to_body_id,\@ships);

Pushes the selected ships from one body to another

=head2 build_ships

=head2 name_ship

=head2 shipyard_slots

=head2 spaceport_slots

=cut
