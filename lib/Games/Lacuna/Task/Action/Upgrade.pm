package Games::Lacuna::Task::Action::Upgrade;

use 5.010;

use Moose;
use List::Util qw(max);

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

has 'start_building_at' => (
    isa     => 'Int',
    is      => 'rw',
    required=> 1,
    default => 1,
    documentation => 'Upgrade buildings if there are less than n buildings in the build queue',
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
            'Oversight Ministry',
            'Security Ministry',
        ]
    },
    documentation => 'Building uprade preferences',
);

sub run {
    my ($self) = @_;
    
    my $university_level = $self->university_level;
    
    #my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        
        my $building_count = 0;
        my @levels;
        my @buildings_end;
        my @buildings = $self->buildings_body($planet_stats->{id});
        
        # Get build queue size
        foreach my $building_data (@buildings) {
            if (defined $building_data->{pending_build}) {
                $building_count ++
                #my $date_end = $self->parse_date($building_data->{pending_build}{end});
                #push(@buildings_end,$date_end);
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
                            if $building_data->{level} > $university_level;
                        next
                            if $building_data->{level} >= $max_level && $check;
                        
                        my $building_class = $self->building_class($building_data->{url});
                        
                        
                        # Check if we can build
                        my $building_object = $building_class->new(
                            client      => $self->client->client,
                            id          => $building_data->{id},
                        );
                        
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
                        
                        next PLANETS;
                    }
                }
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;