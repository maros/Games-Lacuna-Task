package Games::Lacuna::Task::Action::CollectExcavatorBooty;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Ships',
    'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['home_planet'] };

has 'plans' => (
    is              => 'rw',
    isa             => 'ArrayRef[Str]',
    required        => 1,
    documentation   => 'Automatic plans to be transported',
    default         => sub {
        [
            'Grove of Trees',
            'Algae Pond',
            'Amalgus Meadow',
            'Beach [1]',
            'Beach [2]',
            'Beach [3]',
            'Beach [4]',
            'Beach [5]',
            'Beach [6]',
            'Beach [7]',
            'Beach [8]',
            'Beach [9]',
            'Beach [10]',
            'Beach [11]',
            'Beach [12]',
            'Beach [13]',
            'Beeldeban Nest',
            'Crater',
            'Denton Brambles',
            'Geo Thermal Vent',
            'Grove of Trees',
            'Lagoon',
            'Lake',
            'Lapis Forest',
            'Malcud Field',
            'Natural Spring',
            'Patch of Sand',
            'Ravine',
            'Rocky Outcropping',
            'Volcano',
            
            'Citadel of Knope',
            'Black Hole Generator',
            'Oracle of Anid',
            'Temple of the Drajilites',
            'Library of Jith',
            'Kalavian Ruins',
            'Interdimensional Rift',
            'Gratch\'s Gauntlet',
            'Crashed Ship Site',
            'Pantheon of Hagness',
            
        ]
    }
);

has 'extra_build_level' => (
    is              => 'rw',
    isa             => 'Int',
    required        => 1,
    documentation   => 'Ignore plans with extra build level above this value [Default: 2]',
    default         => 2,
);

has 'min_items' => (
    is              => 'rw',
    isa             => 'Int',
    required        => 1,
    documentation   => 'Only send ship if we have n-items to be sent [Default: 1]',
    default         => 1,
);


sub description {
    return q[Ship excavator booty to a selected planet];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    return
        if $planet_stats->{id} == $self->home_planet_data->{id};
        
    # Get trade ministry
    my $tradeministry = $self->find_building($planet_stats->{id},'Trade');
    return 
        unless $tradeministry;
    my $tradeministry_object = $self->build_object($tradeministry);
    
    # Get glyphs
    my $available_glyphs = $self->request(
        object  => $tradeministry_object,
        method  => 'get_glyph_summary',
    );
    
    # Get plans
    my $available_plans = $self->request(
        object  => $tradeministry_object,
        method  => 'get_plan_summary',
    );
    
    my $total_cargo;
    my @cargo;
    
    # Get all glyphs
    foreach my $glyph (@{$available_glyphs->{glyphs}}) {
        push(@cargo,{
            "type"      => "glyph",
            "quantity"  => $glyph->{quantity},
            "name"      => $glyph->{name},
        });
        $total_cargo += $glyph->{quantity} * $available_glyphs->{cargo_space_used_each};
    }
    
    # Get all plans
    PLANS:
    foreach my $plan (@{$available_plans->{plans}}) {
        next PLANS
            unless $plan->{level} == 1;
        next PLANS
            unless $plan->{name} ~~ $self->plans;
        next PLANS
            if $plan->{extra_build_level} > $self->{extra_build_level};
        push(@cargo,{
            "type"              => "plan",
            "quantity"          => $plan->{quantity},
            "plan_type"         => $plan->{plan_type},
            "level"             => $plan->{level},
            "extra_build_level" => $plan->{extra_build_level},
        });
        $total_cargo += $plan->{quantity} * $available_plans->{cargo_space_used_each};
    }
    
    return
        unless scalar @cargo;
    
    return
        if scalar @cargo < $self->min_items;
    
    my $trade_ships = $self->trade_ships($planet_stats->{id},\@cargo);
    my @trade_ships = keys %{$trade_ships};
    
    next TRADE
        if scalar @trade_ships == 0;
    
    $self->log('notice','Sending %i item(s) from %s to %s',scalar(@cargo),$planet_stats->{name},$self->home_planet_data->{name});
    
    foreach my $trade_ship (@trade_ships) {
        $self->request(
            object  => $tradeministry_object,
            method  => 'push_items',
            params  => [ 
                $self->home_planet_data->{id},
                $trade_ships->{$trade_ship}, 
                { ship_id => $trade_ship, stay => 0 } 
            ]
        );
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::CollectExcavatorBooty - Ship excavator booty to a selected planet

=head1 DESCRIPTION

This task automates the shipping of excavator booty (natural plans, old race
plan and glyphs) to another planet.

=cut