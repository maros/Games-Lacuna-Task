package Games::Lacuna::Task::Upgrade;
use Moose;
use 5.010;
with qw(
    Games::Lacuna::Task::Role::Connect
    Games::Lacuna::Task::Role::Logger);

our %BUILDINGS = (
    'Grove of Trees'            => 'ignore',
    'Rocky Outcropping'         => 'ignore',
    'Lake'                      => 'ignore',
    'Patch of Sand'             => 'ignore',
    'Crater'                    => 'ignore',
    
    'Waste Recycling Center'    => 'ignore',
    'Development Ministry'      => 'ignore',
    'Network 19 Affiliate'      => 'ignore',
    'University'                => 'ignore',
    'Observatory'               => 'ignore',
    'Shipyard'                  => 'ignore',
    'Space Port'                => 'ignore',
    
    'Energy Reserve'            => 6,
    'Food Reserve'              => 6,
    'Water Storage Tank'        => 6,

    'Algae Syrup Bottler'       => 5,
    'Malcud Burger Packer'      => 5,

    'Malcud Fungus Farm'        => 4,
    'Mine'                      => 4,

    'Algae Cropper'             => 3,
    'Geo Energy Plant'          => 3,
    'Water Purification Plant'  => 3,

    'Ore Storage Tanks'         => 2,
    'Waste Recycling Center'    => 2,
    'Planetary Command Center'  => 2,

    'Waste Sequestration Well'  => 1,
);

sub run {
    my ($self) = @_;
    
    my $planets = $self->session->planets();
    
    # Loop all planets
    foreach my $planet (@$planets) {
        my $max_level = 1;
        my %upgrade_queue;
        
        # Get max level
        my $university = $planet->get_university();
        $max_level += $university->level
            if defined $university;
        
        # Get all buildings
        my $buildings = $planet->get_buildings();
        foreach my $building (@$buildings) {
            # Check if building is at max level
            next
                if $building->level >= $max_level;
            # Check if construction is under way
            next
                if $building->build_remaining > 0;
            # Check if we know this building type
            unless (defined $BUILDINGS{$building->name}) {
                say('Unknown building type '.$building->name);
                next;
            }
            # Get building priority
            my $priority = $BUILDINGS{$building->name};
            # Check if building should be ignored
            next
                if $priority eq 'ignore';
            # Add to upgrade queue
            $upgrade_queue{$priority} ||= [];
            push(@{$upgrade_queue{$priority}},$building); 
        }
        
        # Process upgrade queue by priority
        #sort values %BUILDINGS
        foreach my $priority (1..10) {
            my @reasons;
            
            # Check queue size
            next
                unless defined $upgrade_queue{$priority}
                && scalar(@{$upgrade_queue{$priority}});
            
            # Loop all buildings in queue
            foreach my $building (sort { $a->level <=> $b->level } 
                @{$upgrade_queue{$priority}}) {
                # Get building data
                my $building_data = $building->view;
                # Check if building is upgradeable
                unless ($building_data->{building}{upgrade}{can}) {
                    unshift(@{$building_data->{building}{upgrade}{reason}},$building->name);
                    push(@reasons,$building_data->{building}{upgrade}{reason});
                    next;
                }
                # Upgrade building
                $building->upgrade();
                say('Upgrading '.$building->name);
                next;
            }
            # Print why we could not upgrade anything
            if (scalar @reasons) {
                say('Cannot upgrade:');
                foreach my $reason (@reasons) {
                    say("* ".$reason->[0].': '.$reason->[2].' ('.$reason->[3].')');
                }
            }
            last;
        }
    }
    
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;