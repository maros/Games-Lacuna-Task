package Games::Lacuna::Task::Action::Astronomy;

use 5.010;

use Moose;
use LWP::Simple;
use Text::CSV;

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

has 'stars' => (
    is          => 'rw',
    isa         => 'ArrayRef',
    lazy_build  => 1,
);

has 'probed_stars' => (
    is          => 'rw',
    isa         => 'ArrayRef',
    lazy_build  => 1,
);

sub run {
    my ($self) = @_;
    
    my $probed_stars = $self->probed_stars();
    
    # Loop all planets again
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        
        # Get observatory
        my $observatory = $self->find_building($planet_stats->{id},'Observatory');
        # Get space port
        my $spaceport = $self->find_building($planet_stats->{id},'Space Port');
        # Get shipyard
        my @shipyards = $self->find_building($planet_stats->{id},'Shipyard');
        
        next 
            unless $observatory && $spaceport;
        
        # Max probes controllable
        my $max_probes = $observatory->{level} * 3;
        
        # Get observatory probed stars
        my $observatory_object = Games::Lacuna::Client::Buildings::Observatory->new(
            client      => $self->client->client,
            id          => $observatory->{id},
        );
        
        my $observatory_data = $self->request(
            object  => $observatory_object,
            method  => 'get_probed_stars',
            params  => [1],
        );
        
        my $can_send_probes = $max_probes - $observatory_data->{star_count};
        
        # Reached max probed stars
        next
            if $can_send_probes == 0;
        
        # Get unprobed stars
        my @unprobed_stars = $self->unprobed_stars($planet_stats->{x},$planet_stats->{y},$can_send_probes);
        
        my $spaceport_object = Games::Lacuna::Client::Buildings::SpacePort->new(
            client      => $self->client->client,
            id          => $spaceport->{id},
        );
        
        # Get all available probes
        my $ships_data = $self->paged_request(
            object  => $spaceport_object,
            method  => 'view_all_ships',
            total   => 'number_of_ships',
            data    => 'ships',
        );
        
        my @avaliable_probes;
        my $building_probes = 0;
        
        SHIPS:
        foreach my $ship (@{$ships_data->{ships}}) {
            next SHIPS
                unless $ship->{type} eq 'probe';
            if ($ship->{task} eq 'Docked') {
                push(@avaliable_probes,$ship->{id});
            } elsif ($ship->{task} eq 'Building') {
                $building_probes ++;
            }
        }
        
        
        my $total_probes = scalar(@avaliable_probes) + $building_probes;
        
        # We have to build new probes
        if ($total_probes < scalar(@unprobed_stars)
            && scalar @shipyards) {
            # Loop all shipyards
            SHIPYARDS:
            foreach my $shipyard (@shipyards) {
                my $shipyard_object = Games::Lacuna::Client::Buildings::Shipyard->new(
                    client      => $self->client->client,
                    id          => $shipyard->{id},
                );
                
                # Repeat until we have enough probes
                SHIPYARD_QUEUE:
                while ($total_probes < scalar(@unprobed_stars)) {
                    my $buildable_ships = $self->request(
                        object  => $shipyard_object,
                        method  => 'get_buildable',
                    );
                    
                    # Check available docks
                    next PLANET
                        if $buildable_ships->{docks_available} == 0;
                    
                    # Check if probe can be built
                    next PLANET
                        if $buildable_ships->{buildable}{probe}{can} == 0;
                    
                    $self->log('notice',"Building probe on %s",$planet_stats->{name});
                    
                    # Build probe
                    $self->request(
                        object  => $shipyard_object,
                        method  => 'build_ship',
                        params  => ['probe'],
                    );
                    
                    $building_probes++;
                    $total_probes = scalar(@avaliable_probes) + $building_probes;
                }
            }
        }
        
        foreach my $star (@unprobed_stars) {
            my $probe = pop(@avaliable_probes);
            if (defined $probe) {
                $self->log('notice',"Sending probe from from %s",$planet_stats->{name});
                
                # Send probe to star
                $self->request(
                    object  => $spaceport_object,
                    method  => 'send_ship',
                    params  => [ $probe,{ "star_id" => $star } ],
                );
                push(@{$probed_stars},$star);
            }
        }
    }
    
    $self->write_cache(
        key     => 'stars/probed',
        value   => $probed_stars,
        max_age => (60*60*24*7), # Cache one week
    );
}

sub unprobed_stars {
    my ($self,$x,$y,$limit) = @_;
    
    $limit //= 1;
    
    my $stars = $self->stars;
    my @star_distance;
    foreach my $star (@{$stars}) {
        my $dist = sqrt( ($star->{x} - $x)**2 + ($star->{y} - $y)**2 );
        push(@star_distance,[$dist,$star->{id}]);
    }
    
    my $probed_stars = $self->probed_stars();
    my @unprobed_stars;
    
    foreach my $star (sort { $a->[0] <=> $b->[0] } @star_distance) {
        my $star_id = $star->[1];
        
        # Check if star has already been probed
        next
            if $star_id ~~ $probed_stars;
        
        # Get star info
        my $star_info = $self->request(
            type    => 'map',
            params  => [ $star_id ],
            method  => 'get_star',
        );
        
        if (defined $star_info->{star}{bodies}
            && scalar(@{$star_info->{star}{bodies}})) {
            push(@{$probed_stars},$star_id);
            next;
        }
        
        # Get incoming probe info
        my $star_incomming = $self->request(
            type    => 'map',
            params  => [ $star_id ],
            method  => 'check_star_for_incoming_probe',
        );
        
        if ($star_incomming->{incoming_probe} > 0) {
            push(@{$probed_stars},$star_id);
            next;
        }
        
        push(@unprobed_stars,$star_id);
        
        return @unprobed_stars
            if scalar(@unprobed_stars) >= $limit
    }
    
    return @unprobed_stars;
}

sub _build_probed_stars {
    my ($self) = @_;
    
    my $probed_stars = $self->lookup_cache('stars/probed');
    
    $probed_stars ||= [];
    
    return $probed_stars;
}

sub _build_stars {
    my ($self) = @_;
    
    my $stars = $self->lookup_cache('stars/all');
    
    return $stars
        if defined $stars;
    
    my $server = $self->lookup_cache('config')->{uri};
    
    return
        unless $server =~ /^https?:\/\/([^.]+)\./;
    
    my $starmap_uri = 'http://'.$1.'.lacunaexpanse.com.s3.amazonaws.com/stars.csv';

    $self->log('debug',"Fetching star map from %s",$starmap_uri);
    
    my @stars;
    my $content = get($starmap_uri);
    
    my $csv = Text::CSV->new ();
    open my $fh, "<:encoding(utf8)", \$content;
    $csv->column_names( $csv->getline($fh) );
    while( my $row = $csv->getline_hr( $fh ) ){
        delete $row->{color};
        push(@stars,$row);
    }
    
    $self->write_cache(
        key     => 'stars/all',
        value   => \@stars,
        max_age => (60*60*24*31), # Cache one month
    );
    
    return \@stars;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;