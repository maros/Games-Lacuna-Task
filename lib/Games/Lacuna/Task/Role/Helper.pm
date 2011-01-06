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
        push(@planets,$self->body_status($planet));
    }
    return @planets;
}

sub body_status {
    my ($self,$body) = @_;
    
    my $key = 'body/'.$body;
    $self->lookup_cache($key) || $self->request(
        type    => 'body',
        id      => $body,
        method  => 'get_status',
    )->{body};
}

sub find_building {
    my ($self,$body,$type) = @_;
    
    # Get buildings
    my @results;
    foreach my $building_data ($self->buildings_body($body)) {
        next
            unless $building_data->{name} eq $type;
        push (@results,$building_data);
    }
    
    @results = (sort { $b->{level} <=> $a->{level} } @results);
    return wantarray ? @results : $results[0];
}

sub buildings_body {
    my ($self,$body) = @_;
    
    my $key = 'body/'.$body.'/buildings';
    my $buildings = $self->lookup_cache($key) || $self->request(
        type    => 'body',
        id      => $body,
        method  => 'get_buildings',
    )->{buildings};
    
    my @results;
    foreach my $building_id (keys %{$buildings}) {
        $buildings->{$building_id}{id} = $building_id;
        push(@results,$buildings->{$building_id});
    }
    return @results;
}

sub building_class {
    my ($self,$url) = @_;
    return "Games::Lacuna::Client::Buildings::".Games::Lacuna::Client::Buildings::type_from_url($url);
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

sub can_afford {
    my ($self,$planet_data,$cost) = @_;
    
    foreach my $ressource (qw(food ore water energy)) {
        return 0
            if ($planet_data->{$ressource.'_stored'} < $cost->{$ressource});
    }
    
    return 0
        if (defined $cost->{waste} 
        && ($planet_data->{'waste_capacity'} - $planet_data->{'waste_stored'}) < $cost->{waste});
    
    return 1;
}

no Moose::Role;
1;
