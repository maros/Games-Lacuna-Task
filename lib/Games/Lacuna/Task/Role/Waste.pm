package Games::Lacuna::Task::Role::Waste;

use 5.010;
use Moose::Role;

use List::Util qw(max sum);

sub disposeable_waste {
    my ($self,$planet_stats) = @_;
    
    my $recycleable_waste = 0;
    my $keep_waste_hours = 24;
    $keep_waste_hours = $self->keep_waste_hours
        if $self->can('keep_waste_hours');
    
    # Get recycleable waste
    if ($planet_stats->{waste_hour} > 0) {
        $recycleable_waste = $planet_stats->{waste_stored};
    } else {
        $recycleable_waste = $planet_stats->{waste_stored} + ($planet_stats->{waste_hour} * $keep_waste_hours)
    }
    
    return max($recycleable_waste,0);
}

sub convert_waste {
    my ($self,$planet_stats,$quantity) = @_;
    
    $self->log('notice','Proucing %i waste on %s',$quantity,$planet_stats->{name});
    
    my @resource_types = @Games::Lacuna::Task::Constants::RESOURCES;
    
    my @resources_ordered = sort { $planet_stats->{$b.'_stored'} <=> $planet_stats->{$a.'_stored'} } @resource_types;
    
    warn join ',',@resources_ordered;
    
    my $resources_total = sum map { $planet_stats->{$_.'_stored'} } @resource_types;
    my $resources_avg = $resources_total / scalar @resource_types;
    
    warn $resources_total.'-'.$resources_avg;
    
    foreach (@resources_ordered) {
        when('ore') {
            
        }
        when('food') {
            
        }
        when('water') {
            
        }
        when('energy') {
            
        }
    }
    
    
    # TODO get distribution center
    # TODO get max resource per type
    # TODO get max resource per subtype (ore,food)
}

no Moose::Role;
1;
