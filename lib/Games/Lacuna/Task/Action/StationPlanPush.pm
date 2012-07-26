package Games::Lacuna::Task::Action::StationPlanPush;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['home_planet','space_station'] };

our @MODULES = (
    'Art Museum',
    'Culinary Institute',
    'Interstellar Broadcast System',
    'Opera House',
    'Parliament',
    'Police Station',
    'Station Command Center',
    'Warehouse',
);

sub description {
    return q[Transport Space Station module plans];
}

sub run {
    my ($self) = @_;
    
    my $planet_home = $self->home_planet_data();
    my $trade_object = $self->get_building_object($planet_home->{id},'Trade');
    
    return $self->abort('Could not find trade ministry')
        unless $trade_object;
    
    my $plans = $self->request(
        object  => $trade_object,
        method  => 'get_plan_summary',
    );
    
    my @modules;
    my $cargo_size = 0;
    my $module_count = 0;
    
    foreach my $plan (@{$plans->{plans}}) {
        next
            unless $plan->{name} ~~ \@MODULES;
        push(@modules,$plan);
        $cargo_size += $plan->{quantity} * $Games::Lacuna::Task::Constants::CARGO{plan};
        $module_count += $plan->{quantity};
        push(@modules, {
            "type"      => "plan",
            "plan_type" => $plan->{plan_type},
            "level"     => $plan->{level},  
            "extra_build_level" => $plan->{extra_build_level},
            "quantity"  => $plan->{quantity},
        });
    }
    
    if (scalar @modules) {
        my $ships = $self->request(
            object  => $trade_object,
            method  => 'get_trade_ships',
        );
        
        my $cargo_ship;
        foreach my $ship (sort { $a->{speed} <=> $b->{speed} } @{$ships->{ships}}) {
            next
                if $ship->{name} =~ m/!/;
            next
                unless $ship->{hold_size} >= $cargo_size;
            $cargo_ship = $ship;
            last;
        }
        
        if ($cargo_ship) {
            $self->log('notice','Shipping %i module plans to %s',$module_count,$self->space_station_data->{name});
            $self->request(
                object  => $trade_object,
                method  => 'push_items',
                params  => [ 
                    $self->space_station_data->{id}, 
                    \@modules, 
                    { 
                        ship_id => $cargo_ship->{id},
                        stay    => 0,
                    } 
                ]
            );
            
        }
        my @cargo;
        
    
    }
    
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;