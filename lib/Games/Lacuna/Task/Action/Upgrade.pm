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
    default => 2,
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
);

sub run {
    my ($self) = @_;
    
    my $university_level = $self->university_level;
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        
        my $building_count = 0;
        my @levels;
        
        my $buildings = $self->buildings_body($planet_stats->{id});
        
        # Get build queue size
        foreach my $building_id (keys %$buildings) {
            $building_count ++
                if defined $buildings->{$building_id}{pending_build};
            push(@levels,$buildings->{$building_id}{level});
        }
        
        my $max_level = max(@levels);
        
        # Check if build queue is filled
        if ($building_count <= $self->start_building_at) {
            # Get first upgradeable building
            for my $check (1,0) {
                foreach my $building_type (@{$self->{upgrade_preference}}) {
                    foreach my $building_id (keys %$buildings) {
                        my $building_data = $buildings->{$building_id};
                        next
                            unless $building_data->{name} eq $building_type;
                        next
                            if $building_data->{pending_build};
                        next
                            if $building_data->{level} > $university_level;
                        next
                            if $building_data->{level} >= $max_level && $check;
                        
                        my $building_class = $self->building_class($building_data->{url});
                        
                        my $building_object = $building_class->new(
                            client      => $self->client->client,
                            id          => $building_id,
                        );
                        
                        my $building_detail = $self->request(
                            object  => $building_object,
                            method  => 'view',
                        );
                        
                        next
                            unless $building_detail->{building}{upgrade}{can};
                        
                        $self->request(
                            object  => $building_object,
                            method  => 'upgrade',
                        );
                        
                        $self->log('notice',"Upgrading %s on %s",$building_type,$planet_stats->{name});
                        
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