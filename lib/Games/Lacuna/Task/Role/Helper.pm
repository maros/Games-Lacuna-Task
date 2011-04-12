package Games::Lacuna::Task::Role::Helper;

use 5.010;
use Moose::Role;

use List::Util qw(max);

use Games::Lacuna::Task::Cache;
use Games::Lacuna::Task::Constants;
use Data::Dumper;
use DateTime;
use Unicode::Normalize;

sub build_object {
    my ($self,$class,@params) = @_;
    
    # Get class and id from status hash
    if (ref $class eq 'HASH') {
        push(@params,'id',$class->{id});
        $class = $class->{url};
    }
    
    # Get class from url
    if ($class =~ m/^\//) {
        $class = 'Buildings::'.Games::Lacuna::Client::Buildings::type_from_url($class);
    }
    
    # Build class name
    $class = 'Games::Lacuna::Client::'.ucfirst($class)
        unless $class =~ m/^Games::Lacuna::Client::(.+)$/;
    
    return $class->new(
        client  => $self->client->client,
        @params
    );
}

sub empire_status {
    my $self = shift;
    
    return $self->lookup_cache('empire')
        || $self->request(
            object      => $self->build_object('Empire'),
            method      => 'get_status',
        )->{empire};
}

sub planets {
    my $self = shift;
    
    my @planets;
    foreach my $planet ($self->planet_ids) {
        push(@planets,$self->body_status($planet));
    }
    return @planets;
}

sub body_status {
    my ($self,$body) = @_;
    
    my $body_id = $self->find_body($body);
    return
        unless $body_id;

    my $key = 'body/'.$body_id;
    my $body_status = $self->lookup_cache($key);
    return $body_status
        if $body_status;
    
    $body_status = $self->request(
        object  => $self->build_object('Body', id => $body_id),
        method  => 'get_status',
    )->{body};
    
    return $body_status;
}

sub find_building {
    my ($self,$body,$type) = @_;
    
    my $body_id = $self->find_body($body);    
    return 
        unless $body_id;

    my $type_url = '/'.lc($type);
    
    # Get buildings
    my @results;
    foreach my $building_data ($self->buildings_body($body_id)) {
        next
            unless $building_data->{name} eq $type
            || $building_data->{url} eq $type_url;
        push (@results,$building_data);
    }
    
    @results = (sort { $b->{level} <=> $a->{level} } @results);
    return wantarray ? @results : $results[0];
}

sub buildings_body {
    my ($self,$body) = @_;
    
    my $body_id = $self->find_body($body);
    return
        unless $body_id;

    my $key = 'body/'.$body_id.'/buildings';
    my $buildings = $self->lookup_cache($key) || $self->request(
        object  => $self->build_object('Body', id => $body_id),
        method  => 'get_buildings',
    )->{buildings};
    
    my @results;
    foreach my $building_id (keys %{$buildings}) {
        $buildings->{$building_id}{id} = $building_id;
        push(@results,$buildings->{$building_id});
    }
    return @results;
}

sub university_level {
    my ($self) = @_;
    
    my @university_levels;
    foreach my $planet ($self->planet_ids) {
        my $university = $self->find_building($planet,'University');
        next 
            unless $university;
        push(@university_levels,$university->{level});
    }
    return max(@university_levels);
}

sub planet_ids {
    my $self = shift;
    
    my $empire_status = $self->empire_status();
    return keys %{$empire_status->{planets}};
}

sub home_planet_id {
    my $self = shift;
    
    my $empire_status = $self->empire_status();
    
    return $empire_status->{home_planet_id};
}

sub delta_date {
    my ($self,$date) = @_;
    
    $date = $self->parse_date($date)
        unless blessed($date) && $date->isa('DateTime');
    
    my $timestamp = DateTime->now->set_time_zone('UTC');
    my $date_delta_ms = $timestamp->delta_ms( $date );
    
    my $delta_days = int($date_delta_ms->delta_minutes / (24*60));
    my $delta_days_rest = $date_delta_ms->delta_minutes % (24*60);
    my $delta_hours = int($delta_days_rest / 60);
    my $delta_hours_rest = $delta_days_rest % 60;
    
    my $return = sprintf('%02im:%02is',$delta_hours_rest,$date_delta_ms->seconds);
    
    if ($delta_hours) {
        $return = sprintf('%02ih:%s',$delta_hours,$return);
    }
    if ($delta_days) {
        $return = sprintf('%02id %s',$delta_days,$return);
    }
    
    return $return;
    
    
#    return DateTime::Duration->new(
#        years       => 0,
#        months      => 0,
#        weeks       => 0,
#        days        => $delta_days,
#        hours       => $delta_hours,
#        minutes     => $delta_hours_rest,
#        seconds     => $date_delta_ms->seconds,
#    );
}

sub parse_date {
    my ($self,$date) = @_;
    
    return
        unless defined $date;
    
    if ($date =~ m/^
        (?<day>\d{2}) \s
        (?<month>\d{2}) \s
        (?<year>20\d{2}) \s
        (?<hour>\d{2}) :
        (?<minute>\d{2}) :
        (?<second>\d{2}) \s
        \+(?<timezoneoffset>\d{4})
        $/x) {
        $self->log('warn','Unexpected timezone offset %04i',$+{timezoneoffset})
            if $+{timezoneoffset} != 0;
        return DateTime->new(
            (map { $_ => $+{$_} } qw(year month day hour minute second)),
            time_zone   => 'UTC',
        );
    }
    
    return;
}

sub find_body {
    my ($self,$body) = @_;

    return
        unless $body;

    return $body
        if $body =~ m/^\d+$/;

    # Get my planets
    my $planets = $self->empire_status->{planets};

    # Exact match
    foreach my $id (keys %$planets) {
        return $id
            if $planets->{$id} eq $body;
    }

    my $name_simple = Unicode::Normalize::decompose($body); 
    $name_simple =~ s/\p{NonSpacingMark}//g;
    $name_simple = uc($name_simple);
    
    # Similar match
    foreach my $id (keys %$planets) {
        my $name_compare = Unicode::Normalize::decompose($planets->{$id}); 
        $name_compare =~ s/\p{NonSpacingMark}//g;
        $name_compare = uc($name_compare);
        return $id
            if $name_simple eq $name_compare;
    }

    return;
}

sub can_afford {
    my ($self,$planet_data,$cost) = @_;
    
    unless (ref($planet_data) eq 'HASH') {
        $planet_data = $self->body_status($self->find_body($planet_data));
    }
    
    foreach my $ressource (qw(food ore water energy)) {
        return 0
            if (( $planet_data->{$ressource.'_stored'} - 1000 ) < $cost->{$ressource});
    }
    
    return 0
        if (defined $cost->{waste} 
        && ($planet_data->{'waste_capacity'} - $planet_data->{'waste_stored'}) < $cost->{waste});
    
    return 1;
}

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Role::Helper - Various helper methods

=head1 METHODS

=head2 body_status

 my $body_status = $self->body_status($body_id OR $body_name);

Returns the status hash of a given body/planet.

=head2 buildings_body

 my $body_buildings = $self->buildings_body($body_id OR $body_name);

Returns all buildings for a given planet.

=head2 empire_status

Returns the empire status hash

=head2 build_object

 my $glc_object = $self->build_object('/university', id => $building_id);
 OR
 my $glc_object = $self->build_object($building_status_response);
 OR
 my $glc_object = $self->build_object('Spaceport', id => $building_id);
 OR
 my $glc_object = $self->build_object('Map');

Returns a L<Game::Lacuna::Client::*> object

=head2 can_afford

 $self->can_afford($planet_id,$cost_hash);
 OR
 $self->can_afford($planet_stats_hash,$cost_hash);

Calculates if the upgrade/repair can be afforded

=head2 find_building

 my @spaceports = $self->find_building($body_id or $body_name,'Space Port');

Finds all buildings on a given body of a given type ordered by level.

=head2 find_body

 my $body_id = $self->find_body($body_name);

Returns the body ID for the given body name. Ignores case and accents
so that eg. 'Hà Nôi' equals 'HA NOI'.

=head2 home_planet_id

Returns the id of the empire' home planet id

=head2 planet_ids

Returns the empire' planet ids

=head2 planets

Returns the empire' planet status hashes

=head2 university_level

Returns your empire' university level

=head2 delta_date

 $self->delta_date($date);

Returns a human readable delta for the given date

=head2 parse_date

Returns a DateTime object for the given date

=cut


no Moose::Role;
1;
