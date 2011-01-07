package Games::Lacuna::Task::Action::Astronomy;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger
    Games::Lacuna::Task::Role::Stars
    Games::Lacuna::Task::Role::Ships);

sub description {
    return q[This task automates the task of probing stars];
}

after 'run' => sub {
    my ($self) = @_;
    $self->save_probed_stars()
};

sub process_planet {
    my ($self,$planet_stats) = @_;
        
    # Get observatory
    my $observatory = $self->find_building($planet_stats->{id},'Observatory');
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'Space Port');
    
    return 
        unless $observatory && $spaceport;
    
    # Max probes controllable
    my $max_probes = $observatory->{level} * 3;
    
    # Get observatory probed stars
    
    my $observatory_object = $self->build_object($observatory);
    my $observatory_data = $self->request(
        object  => $observatory_object,
        method  => 'get_probed_stars',
        params  => [1],
    );
    
    my $can_send_probes = $max_probes - $observatory_data->{star_count};
    
    # Reached max probed stars
    return
        if $can_send_probes == 0;
    
    # Get available probes
    my @avaliable_probes = $self->ships(
        planet          => $planet_stats,
        ships_needed    => $can_send_probes,
        ship_type       => 'probe',
    );
    
    # Send available probes to stars
    if (scalar @avaliable_probes) {
        my $spaceport_object = $self->build_object($spaceport);
        
        # Get unprobed stars
        my @unprobed_stars = $self->closest_unprobed_stars($planet_stats->{x},$planet_stats->{y},scalar(@avaliable_probes));
        
        foreach my $star (@unprobed_stars) {
            my $probe = pop(@avaliable_probes);
            if (defined $probe) {
                
                # Send probe to star
                my $response = $self->request(
                    object  => $spaceport_object,
                    method  => 'send_ship',
                    params  => [ $probe,{ "star_id" => $star } ],
                );
                $self->add_probed_star($star);
                
                $self->log('notice',"Sending probe from from %s to %s",$planet_stats->{name},$response->{ship}{to}{name});
            }
        }
    }
}

sub closest_unprobed_stars {
    my ($self,$x,$y,$limit) = @_;
    
    $limit //= 1;
    
    my @unprobed_stars;
    
    STARS:
    foreach my $star ($self->stars_by_distance($x,$y)) {
        
        # Check if star has already been probed
        next STARS
            if $self->is_probed_star($star->{id});
        
        # Get star info
        my $star_info = $self->request(
            object  => $self->build_object('Map'),
            params  => [ $star->{id} ],
            method  => 'get_star',
        );
        
        if (defined $star_info->{star}{bodies}
            && scalar(@{$star_info->{star}{bodies}})) {
            $self->add_probed_star($star->{id});
            next;
        }
        
        # Get incoming probe info
        my $star_incomming = $self->request(
            object  => $self->build_object('Map'),
            params  => [ $star->{id} ],
            method  => 'check_star_for_incoming_probe',
        );
        
        if ($star_incomming->{incoming_probe} > 0) {
            $self->add_probed_star($star->{id});
            next;
        }
        
        push(@unprobed_stars,$star->{id});
        
        last STARS
            if scalar(@unprobed_stars) >= $limit;
    }
    
    return @unprobed_stars;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;