package Games::Lacuna::Task::Action::UpgradeResource;

use 5.010;

use List::Util qw(min max sum);

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Building);

has 'water_buildings' => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub { [qw(AtmosphericEvaporator WaterProduction WaterPurification WaterReclamation WasteTreatment WasteExchanger)] },
    documentation => 'Handled water production buildings',
);

has 'food_buildings' => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub { [qw(Algae Apple Bean Beeldeban Corn Dairy Denton Lapis Malcud Potato Wheat)] },
    documentation => 'Handled food production buildings',
);

has 'ore_buildings' => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub { [qw(Mine MiningMinistry OreRefinery WasteTreatment WasteDigester WasteTreatment WasteExchanger)] },
    documentation => 'Handled ore production buildings',
);

has 'energy_buildings' => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub { [qw(Fission Fusion Geo HydroCarbon Singularity WasteEnergy WasteTreatment WasteExchanger)] },
    documentation => 'Handled energy production buildings',
);

has 'start_building_at' => (
    isa     => 'Int',
    is      => 'rw',
    required=> 1,
    default => 0,
    documentation => 'Upgrade buildings if there are less than N buildings in the build queue',
);

sub description {
    return q[This task handles the upgrade of resource buildings if a resource is running low];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $building_count = 0;
    my @levels;
    my @buildings = $self->buildings_body($planet_stats->{id});
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Get build queue size
    foreach my $building_data (@buildings) {
        if (defined $building_data->{pending_build}) {
            my $date_end = $self->parse_date($building_data->{pending_build}{end});
            $building_count ++
                if $timestamp < $date_end;
        }
    }

    # Check if build queue is filled
    return
        if ($building_count > $self->start_building_at);
    
    # Calc max level for resource buildings
    my $max_ressouce_level = $self->max_resource_building_level($planet_stats->{id});
    
    # Get current resource production
    my %resources_production;
    {
        no warnings 'once';
        foreach my $resource (@Games::Lacuna::Task::Constants::RESOURCES_ALL) {
            $resources_production{$resource} = $planet_stats->{$resource.'_hour'};
        }
    }
    
    # Get upgrade preference
    my @upgrade_resource_types = 
        sort { $resources_production{$a} <=> $resources_production{$b} }
        keys %resources_production;
    
    # Loop resource types
    RESOURCE_TYPE:
    foreach my $resource_type (@upgrade_resource_types) {
        my $building_method = $resource_type.'_buildings';
        my $available_buildings = $self->$building_method;
        
        BUILDING:
        foreach my $building_data (sort { $a->{level} <=> $b->{level} } @buildings) {
            
            my $building_type = Games::Lacuna::Client::Buildings::type_from_url($building_data->{url});
            
            next BUILDING
                unless $building_type ~~ $available_buildings;
            
            next BUILDING
                if $building_data->{level} >= $max_ressouce_level;
            
            next BUILDING
                unless $building_data->{efficiency} == 100;
            
            if (defined $building_data->{pending_build}) {
                my $date_end = $self->parse_date($building_data->{pending_build}{end});
                next BUILDING
                    if $timestamp < $date_end;
            }
            
            my $upgraded = $self->upgrade_building($planet_stats,$building_data);
            
            $building_count ++
                if $upgraded;
                
            return
                if ($building_count > $self->start_building_at);
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
