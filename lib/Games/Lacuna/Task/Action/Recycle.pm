package Games::Lacuna::Task::Action::Recycle;

use 5.010;

use List::Util qw(min);

use Moose;
extends qw(Games::Lacuna::Task::Action);

sub description {
    return q[This task automates the recycling of waste in the Waste Recycling Center];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $timestamp = DateTime->now->set_time_zone('UTC');
    my %ressources;
    my $total_ressources = 0;
    my $total_ressources_coeficient = 0;
    my $total_waste_coeficient = 0;
    my $recycleable_waste = 0;
    my $waste = $planet_stats->{waste_stored};
    
    # Get recycleable waste
    if ($planet_stats->{waste_hour} > 0) {
        $recycleable_waste = $waste;
    } else {
        $recycleable_waste = $waste + ($planet_stats->{waste_hour} * 12)
    }
    
    # Get stored ressources
    foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
        my $stored = $planet_stats->{$ressource.'_stored'}+0;
        my $capacity = $planet_stats->{$ressource.'_capacity'}+0;
        $ressources{$ressource} = [ $capacity-$stored, 0, 0];
        $total_ressources += $capacity-$stored;
    }
    
    # Fallback if storage is full
    if ($total_ressources == 0) {
        foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
            my $capacity = $planet_stats->{$ressource.'_capacity'}+0;
            $ressources{$ressource}[0] = $capacity;
            $total_ressources += $capacity;
        }
    }
    
    # Calculate ressouces
    foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
        $ressources{$ressource}[1] =  ($ressources{$ressource}[0] / $total_ressources);
        if ($ressources{$ressource}[1] > 0
            && $ressources{$ressource}[1] < 1) {
            $ressources{$ressource}[1] = 1-($ressources{$ressource}[1]);
        }
        $total_ressources_coeficient += $ressources{$ressource}[1];
    }
    
    # Calculate recycling relations
    foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
        $ressources{$ressource}[2] = ($ressources{$ressource}[1] / $total_ressources_coeficient);
    }
    
    my @recycling_buildings = $self->find_building($planet_stats->{id},'Waste Recycling Center');
    
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
        
        my %recycle = (map { $_ => int($ressources{$_}[2] * $recycle_quantity) } keys %ressources);
        
        $self->log('notice',"Recycling %i %s, %i %s, %i %s on %s",(map { ($recycle{$_},$_) } @Games::Lacuna::Task::Constants::RESSOURCES),$planet_stats->{name});
        
        $self->request(
            object  => $recycling_object,
            method  => 'recycle',
            params  => [ (map { $recycle{$_} } @Games::Lacuna::Task::Constants::RESSOURCES) ],
        );
        
        $recycleable_waste -= $recycle_quantity;
        
        $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;