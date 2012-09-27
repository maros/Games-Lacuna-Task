package Games::Lacuna::Task::Action::StationPlanPush;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::Ships',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['space_station'] };

sub description {
    return q[Transport Space Station module plans];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $trade_object = $self->get_building_object($planet_stats->{id},'Trade');
    my $space_station_lab = $self->get_building_object($planet_stats->{id},'SSLA');
    
    return
        unless $trade_object
        && $space_station_lab;
    
    my $plans = $self->request(
        object  => $trade_object,
        method  => 'get_plan_summary',
    );
    
    my @modules;
    my $cargo_size = 0;
    my $module_count = 0;
    
    foreach my $plan (@{$plans->{plans}}) {
        next
            unless grep { $plan->{name} eq $_ } values %Games::Lacuna::Task::Constants::MODULES;
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
    
    return
        unless scalar @modules;
    
    my $trade_ships = $self->trade_ships($planet_stats->{id},\@modules);
    my @trade_ships = keys %{$trade_ships};
    
    next TRADE
        if scalar @trade_ships == 0;
    
    $self->log('notice','Shipping %i module plans to %s',$module_count,$self->space_station_data->{name});
    
    foreach my $trade_ship (@trade_ships) {
        $self->request(
            object  => $trade_object,
            method  => 'push_items',
            params  => [ 
                $self->space_station_data->{id},
                $trade_ships->{$trade_ship}, 
                { ship_id => $trade_ship, stay => 0 } 
            ]
        );
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=pod

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::StationPlanPush - Transport Space Station module plans

=head1 DESCRIPTION

This task automates the transport of space station modules to a selected
space station

=cut