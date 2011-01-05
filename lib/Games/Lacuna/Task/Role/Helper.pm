package Games::Lacuna::Task::Role::Helper;

use 5.010;
use Moose::Role;

use List::Util qw(max);

use Games::Lacuna::Task::Cache;
use Games::Lacuna::Task::Constants;
use Data::Dumper;

sub empire_status {
    my $self = shift;
    
    return $self->lookup_cache('empire')
        || $self->request(
            type    => 'empire',
            method  => 'get_status',
        )->{empire};
}

sub planets {
    my $self = shift;
    
    my @planets;
    foreach my $planet ($self->planet_ids) {
        push(@planets,$self->body($planet));
    }
    return @planets;
}

sub body {
    my ($self,$body) = @_;
    
    my $key = 'body/'.$body;
    $self->lookup_cache($key) || $self->request(
        type    => 'body',
        id      => $body,
        method  => 'get_status',
    )->{body};
}

sub building_class {
    my ($self,$url) = @_;
    
    return "Games::Lacuna::Client::Buildings::".Games::Lacuna::Client::Buildings::type_from_url($url);
}

sub building_type_single {
    my ($self,$body,$type) = @_;
    
    my $buildings = $self->building_type($body,$type);
    
    return
        unless scalar keys %{$buildings};
    
    my @result = sort { $b->{level} <=> $a->{level} } values %{$buildings};
    return $result[0];
}

sub building_type {
    my ($self,$body,$type) = @_;
    
    # Get recycling center
    my $buildings = $self->buildings_body($body);
    
    # Get buildings
    my %buildings;
    foreach my $building_id (keys %{$buildings}) {
        my $building_data = $buildings->{$building_id};
        next
            unless $building_data->{name} eq $type;
        $building_data->{id} ||= $building_id;
        $buildings{$building_id} = $building_data;
    }
    
    return \%buildings;
}

sub university_level {
    my ($self) = @_;
    
    my @university_levels;
    foreach my $planet ($self->planet_ids) {
        my $university = $self->building_type_single($planet,'University');
        next 
            unless $university;
        push(@university_levels,$university->{level});
    }
    return max(@university_levels);
}

sub buildings_body {
    my ($self,$body) = @_;
    
    my $key = 'body/'.$body.'/buildings';
    $self->lookup_cache($key) || $self->request(
        type    => 'body',
        id      => $body,
        method  => 'get_buildings',
    )->{buildings};
}

sub planet_ids {
    my $self = shift;
    
    my $empire_status = $self->empire_status();
    return keys %{$empire_status->{planets}};
}

sub home_planet_id {
    my $self = shift;
    
    my $empire_status = $self->empire_status;
    return $empire_status->{home_planet_id};
}


no Moose::Role;
1;
