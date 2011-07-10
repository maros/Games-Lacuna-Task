package Games::Lacuna::Task::Action::Recycle;

use 5.010;

use List::Util qw(min);

use Moose;
extends qw(Games::Lacuna::Task::Action);

our @RESOURCES_RECYCLEABLE = qw(water ore energy);

sub description {
    return q[This task automates the recycling of waste in the Waste Recycling Center];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $timestamp = DateTime->now->set_time_zone('UTC');
    my %resources;
    my $total_resources = 0;
    my $total_resources_coeficient = 0;
    my $total_waste_coeficient = 0;
    my $recycleable_waste = 0;
    my $waste = $planet_stats->{waste_stored};
    
    # Get recycleable waste
    if ($planet_stats->{waste_hour} > 0) {
        $recycleable_waste = $waste;
    } else {
        $recycleable_waste = $waste + ($planet_stats->{waste_hour} * 24)
    }
    
    return
        if $recycleable_waste <= 0;
    
    # Get stored resources
    foreach my $resource (@RESOURCES_RECYCLEABLE) {
        my $stored = $planet_stats->{$resource.'_stored'}+0;
        my $capacity = $planet_stats->{$resource.'_capacity'}+0;
        $resources{$resource} = [ $capacity-$stored, 0, 0];
        $total_resources += $capacity-$stored;
    }
    
    # Fallback if storage is full
    if ($total_resources == 0) {
        foreach my $resource (@RESOURCES_RECYCLEABLE) {
            my $capacity = $planet_stats->{$resource.'_capacity'}+0;
            $resources{$resource}[0] = $capacity;
            $total_resources += $capacity;
        }
    }
    
    # Calculate ressouces
    foreach my $resource (@RESOURCES_RECYCLEABLE) {
        $resources{$resource}[1] =  ($resources{$resource}[0] / $total_resources);
        if ($resources{$resource}[1] > 0
            && $resources{$resource}[1] < 1) {
            $resources{$resource}[1] = 1-($resources{$resource}[1]);
        }
        $total_resources_coeficient += $resources{$resource}[1];
    }
    
    # Calculate recycling relations
    foreach my $resource (@RESOURCES_RECYCLEABLE) {
        $resources{$resource}[2] = ($resources{$resource}[1] / $total_resources_coeficient);
    }
    
    my @recycling_buildings = $self->find_building($planet_stats->{id},'WasteRecycling');
    
    # Loop all recycling buildings
    foreach my $recycling_building (@recycling_buildings) {
        
        last
            if $recycleable_waste == 0;
        
        # Check recycling is busy
        if (defined $recycling_building->{work}) {
            my $work_end = $self->parse_date($recycling_building->{work}{end});
            if ($work_end > $timestamp) {
                next;
            }
        }
        
        my $recycling_object = $self->build_object($recycling_building);
        my $recycling_data = $self->request(
            object  => $recycling_object,
            method  => 'view',
        );
        
        my $recycle_quantity = min($recycleable_waste,$recycling_data->{recycle}{max_recycle});
        
        my %recycle = (map { $_ => int($resources{$_}[2] * $recycle_quantity) } keys %resources);
        
        $self->log('notice',"Recycling %i %s, %i %s, %i %s on %s",(map { ($recycle{$_},$_) } @RESOURCES_RECYCLEABLE),$planet_stats->{name});
        
        $self->request(
            object  => $recycling_object,
            method  => 'recycle',
            params  => [ (map { $recycle{$_} } @RESOURCES_RECYCLEABLE) ],
        );
        
        $recycleable_waste -= $recycle_quantity;
        
        $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
