package Games::Lacuna::Task::Action::Upgrade;

use 5.010;

use List::Util qw(max);

use Moose;
extends qw(Games::Lacuna::Task::Action);

has 'start_building_at' => (
    isa     => 'Int',
    is      => 'rw',
    required=> 1,
    default => 1,
    documentation => 'Upgrade buildings if there are less than N buildings in the build queue',
);

has 'upgrade_preference' => (
    isa     => 'ArrayRef[Str]',
    is      => 'rw',
    default => sub {
        [
            'Waste Sequestration Well',
            'Ore Storage Tanks',
            'Water Storage Tank',
            'Food Reserve',
            'Energy Reserve',
            'Planetary Command Center',
            'Stockpile',
        ]
    },
    documentation => 'Building uprade preferences',
);

sub description {
    return q[This task automates the upgrading of buildings if the build queue is empty];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $building_count = 0;
    my @levels;
    my @buildings_end;
    my @buildings = $self->buildings_body($planet_stats->{id});
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
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
    
    # Check if build queue is filled
    if ($building_count <= $self->start_building_at) {
        for my $check (1,0) {
            # Loop all building types
            foreach my $building_type (@{$self->{upgrade_preference}}) {
                # Loop all buildings
                foreach my $building_data (@buildings) {
                    next
                        unless $building_data->{name} eq $building_type;
                    next
                        if $building_data->{pending_build};
                    next
                        if $building_data->{level} > $self->university_level;
                    next
                        if $building_data->{level} >= $max_level && $check;
                    
                    my $building_object = $self->build_object($building_data);
                    my $building_detail = $self->request(
                        object  => $building_object,
                        method  => 'view',
                    );
                    
                    next
                        unless $building_detail->{building}{upgrade}{can};
                    
                    # Check if upgraded building is sustainable
                    foreach my $ressource (qw(ore food energy water)) {
                        my $ressource_difference = -1 * ($building_detail->{'building'}{$ressource.'_hour'} - $building_detail->{'building'}{upgrade}{production}{$ressource.'_hour'});
                        next
                            if ($planet_stats->{$ressource.'_hour'} + $ressource_difference <= 0);
                    }
                    
                    # Check if we really can afford the upgrade
                    next
                        unless $self->can_afford($planet_stats,$building_detail->{'building'}{upgrade}{cost});
                    
                    $self->log('notice',"Upgrading %s on %s",$building_type,$planet_stats->{name});
                    
                    # Upgrade request
                    $self->request(
                        object  => $building_object,
                        method  => 'upgrade',
                    );
                    
                    $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
                    return;
                }
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;