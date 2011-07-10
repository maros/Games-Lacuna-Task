package Games::Lacuna::Task::Role::Waste;

use 5.010;
use Moose::Role;


sub recycleable_waste {
    my ($self,$planet_stats) = @_;
    
    my $recycleable_waste = 0;
    
    # Get recycleable waste
    if ($planet_stats->{waste_hour} > 0) {
        $recycleable_waste = $planet_stats->{waste_stored};
    } else {
        $recycleable_waste = $planet_stats->{waste_stored} + ($planet_stats->{waste_hour} * 24)
    }
    
    return $recycleable_waste;
}

no Moose::Role;
1;
