package Games::Lacuna::Task::Action::Upgrade;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Building',
    'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['start_building_at'] };

use List::Util qw(max);
use Games::Lacuna::Task::Utils qw(parse_date);

has 'upgrade_preference' => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub {
        [
            'WasteSequestration',
            'OreStorage',
            'WaterStorage',
            'FoodReserve',
            'EnergyReserve',
            'Stockpile',
            'PlanetaryCommand',
            'DistributionCenter',
        ]
    },
    documentation => 'Building uprade preferences',
);

sub description {
    return q[This task automates basic upgrading of buildings if the build queue is empty];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $building_count = 0;
    my @levels;
    my @buildings_end;
    my @buildings = $self->buildings_body($planet_stats->{id});
    my $timestamp = time();
    
    # Get build queue size
    foreach my $building_data (@buildings) {
        next
            if $building_data->{name} eq 'Supply Pod';
        if (defined $building_data->{pending_build}) {
            my $date_end = parse_date($building_data->{pending_build}{end});
            $building_count ++
                if $timestamp < $date_end;
        }
        push(@levels,$building_data->{level});
    }
    my $max_level = max(@levels);
    
    # Check if build queue is filled
    return
        if ($building_count > $self->start_building_at);
    
    $self->log('debug','Start building');
    for my $check (1,0) {
        # Loop all building types
        foreach my $building_type (@{$self->{upgrade_preference}}) {
            # Loop all buildings
            foreach my $building_data (@buildings) {
                next
                    unless Games::Lacuna::Client::Buildings::type_from_url($building_data->{url}) eq $building_type;
                next
                    if $building_data->{pending_build};
                next
                    if $building_data->{level} > $self->university_level;
                next
                    if $building_data->{level} >= $max_level && $check;
                next
                    unless $self->check_upgrade_building($planet_stats,$building_data);
                
                $self->upgrade_building($planet_stats,$building_data);
                
                return;
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
