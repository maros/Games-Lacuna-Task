package Games::Lacuna::Task::Action::VrbanskDistribute;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::Ships',
    'Games::Lacuna::Task::Role::Storage',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['home_planet'] };

has 'count' => (
    isa         => 'Int',
    is          => 'ro',
    required    => 1,
    default     => 50,
    documentation=> "Number of halls to be available at every colony [Default: 50]",
);

sub description {
    return q[Distribute Halls of Vrbansk];
}

sub process_planet {
    my ($self,$planet_stats) = @_;

    my $plans_stored = $self->plans_stored($planet_stats->{id});
    
    my ($plans) = 0;
    foreach my $plan (@{$plans_stored}) {
        next
            unless $plan->{name} eq 'Halls of Vrbansk';
            
        $plans = $plan->{quantity};
        last;
    }
    
    if ($plans < $self->count) {
        my $planet_home = $self->home_planet_data();
        my $tradeministry_object = $self->get_building_object($planet_home,'Trade');
        
        my $needed = $self->count - $plans;
    
        return $self->abort('Could not find trade ministry')
            unless $tradeministry_object;
        
        $self->log('notice','Sending %i halls from %s to %s',$needed,$self->home_planet_data->{name},$planet_stats->{name});
        
        my $cargo = [
            {
                type                => 'plan',
                plan_type           => 'Permanent_HallsOfVrbansk',
                level               => 1,
                extra_build_level   => 0,
                quantity            => $needed,
            }
        ];
        
        my $trade_ships = $self->trade_ships($planet_home->{id},$cargo);
        
        foreach my $trade_ship (keys %{$trade_ships}) {
            $self->request(
                object  => $tradeministry_object,
                method  => 'push_items',
                params  => [ 
                    $planet_stats->{id},
                    $trade_ships->{$trade_ship}, 
                    { ship_id => $trade_ship, stay => 0 } 
                ]
            );
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;