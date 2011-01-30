package Games::Lacuna::Task::Action::UpgradeRessource;

use 5.010;

use List::Util qw(min max sum);

use Moose;
extends qw(Games::Lacuna::Task::Action);


has 'water_buildings' => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub { [qw(AtmosphericEvaporator WaterProduction WaterPurification)] },
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
    default => sub { [qw(Mine MiningMinistry OreRefinery)] },
    documentation => 'Handled ore production buildings',
);

has 'energy_buildings' => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub { [qw(Fission Fusion Geo HydroCarbon Singularity)] },
    documentation => 'Handled energy production buildings',
);

has 'ressource_avg' => (
    isa     => 'Int',
    is      => 'rw',
    default => '75',
    documentation => 'Start upgradeing a ressource building if production reaces only n-% of the planets average production',
);


sub description {
    return q[This task handles the upgrade of ressource buildings if a ressource is running low];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $building_count = 0;
    my @levels;
    my @buildings = $self->buildings_body($planet_stats->{id});
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Calc max level for ressource buildings
    my $max_ressouce_level = 15;
    my $stockpile = $self->find_building($planet_stats->{id},'Stockpile');
    if (defined $stockpile) {
       $max_ressouce_level += sprintf("%i",$stockpile->{level}/3);
    }
    my $university_level = $self->university_level + 1;
    $max_ressouce_level = min($max_ressouce_level,$university_level);
    
    # Get build queue size
    foreach my $building_data (@buildings) {
        if (defined $building_data->{pending_build}) {
            my $date_end = $self->parse_date($building_data->{pending_build}{end});
            $building_count ++
                if $timestamp < $date_end;
        }
        push(@levels,$building_data->{level});
    }
    my $max_level = max(@levels);
    
    # Get current ressource production
    my %ressources_production;
    foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
        $ressources_production{$ressource} = $planet_stats->{$ressource.'_hour'};
    }
    
    # Check ressource productiona average
    my $ressources_avg = sum(values %ressources_production) / 4;
    my %ressources_coeficient;
    foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
        $ressources_coeficient{$ressource} = $ressources_production{$ressource} / $ressources_avg * 100;
    }
    
    return
        if (min(values %ressources_coeficient) > $self->ressource_avg);
    
    #TODO: check if buildings are less than $max_ressouce_level
    #TODO: check if build queue is not full
    #TODO: check if ressource buildings are already being upgraded
    
#    # Check if build queue is filled
#    if ($building_count <= $self->start_building_at) {
#        for my $check (1,0) {
#            # Loop all building types
#            foreach my $building_type (@{$self->{upgrade_preference}}) {
#                # Loop all buildings
#                foreach my $building_data (@buildings) {
#                    next
#                        unless $building_data->{name} eq $building_type;
#                    next
#                        if $building_data->{pending_build};
#                    next
#                        if $building_data->{level} > $self->university_level;
#                    next
#                        if $building_data->{level} >= $max_level && $check;
#                    
#                    my $building_object = $self->build_object($building_data);
#                    my $building_detail = $self->request(
#                        object  => $building_object,
#                        method  => 'view',
#                    );
#                    
#                    next
#                        unless $building_detail->{building}{upgrade}{can};
#                    
#                    # Check if upgraded building is sustainable
#                    foreach my $ressource (qw(ore food energy water)) {
#                        my $ressource_difference = -1 * ($building_detail->{'building'}{$ressource.'_hour'} - $building_detail->{'building'}{upgrade}{production}{$ressource.'_hour'});
#                        next
#                            if ($planet_stats->{$ressource.'_hour'} + $ressource_difference <= 0);
#                    }
#                    
#                    # Check if we really can afford the upgrade
#                    next
#                        unless $self->can_afford($planet_stats,$building_detail->{'building'}{upgrade}{cost});
#                    
#                    $self->log('notice',"Upgrading %s on %s",$building_type,$planet_stats->{name});
#                    
#                    # Upgrade request
#                    $self->request(
#                        object  => $building_object,
#                        method  => 'upgrade',
#                    );
#                    
#                    $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
#                    return;
#                }
#            }
#        }
#    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;