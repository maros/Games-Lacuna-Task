package Games::Lacuna::Task::Role::Helper;

use 5.010;
use Moose::Role;

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

sub building_type_single {
    my ($self,$body,$type) = @_;
    
    my $buildings = $self->building_type($body,$type);
    
    return
        unless scalar keys %{$buildings};
        
    my ($building) = (values %$buildings);
    return $building;
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


#sub home_planet {
#    my $self = shift;
#    my $home_planet = $self->client->client->body( id => $self->home_planet_id );
#}
#
#sub home_planet_id {
#    my $self = shift;
#    return $self->empire_stats->{home_planet_id};
#}
#

#
#sub empire_stats {
#    my $self = shift;
#    my $status = $self->cache_request(
#        type    => 'empire',
#        method  => 'get_status',
#    );
#    return $status->{empire}
#        if defined $status;
#}
#
#sub body_stats {
#    my ($self,$id) = @_;
#    $self->cache_request(
#        type    => 'body',
#        id      => $id || $self->home_planet_id,
#        method  => 'get_status',
#        max_age => 60*15,
#        force   => 1,
#    )->{body}
#}
#
#sub building_stats {
#    my ($self,$id) = @_;
#    $self->cache_request(
#        type    => 'building',
#        id      => $id,
#        method  => 'view',
#        force   => 1,
#    )->{building}
#}
#
#sub cache_add {
#    my ($self,$key,$value) = @_;
#}

sub request {
    my ($self,%params) = @_;
    
    my $method = delete $params{method};
    my $type = delete $params{type};
    
    $self->log('debug',"Run external request %s/%s",$type,$method);
    my $request = $self
        ->client
        ->client
        ->$type(%params,verbose_rpc => 1)
        ->$method();
    
    my $status = $request->{status} || $request;
    if ($status->{empire}) {
        $self->write_cache(
            key     => 'empire',
            value   => $status->{empire},
            max_age => 21600,
        );
    }
    if ($status->{body}) {
        $self->write_cache(
            key     => 'body/'.$params{id},
            value   => $status->{body},
        );
    }
    if ($request->{buildings}) {
        $self->write_cache(
            key     => 'body/'.$params{id}.'/buildings',
            value   => $request->{buildings},
            max_age => 600,
        );
    }
    
    return $request;
}

sub lookup_cache {
    my ($self,$key) = @_;
    
    my $storage = $self->client->storage;
    my $cache = $storage->lookup($key);
    return
        unless defined $cache;
    if (blessed $cache
        && $cache->isa('Games::Lacuna::Task::Cache')) {
        return $cache->value
    } else {
        return $cache;
    }
}

sub write_cache {
    my ($self,%params) = @_;
    
    my $storage = $self->client->storage;
    $params{max_age} += time()
        if $params{max_age};
   
    my $cache = Games::Lacuna::Task::Cache->new(
        %params
    );
    
    $cache->store($storage);
    
    return $cache;
}


#sub cache_request {
#    my ($self,%params) = @_;
#    
#    
#    my $type = $params{type};
#    
#    my $lookup_key = join ('/',grep { defined $_ } ($params{type},$params{method},$params{id}));
#    my $cache = $storage->lookup($lookup_key);
#    
#    if ($cache) {
#        return $cache->value
#            if $cache->is_valid && ! $params{force};
#    }
#    
#
#    
#
#    
#    my %cache_params = (
#        key     => $lookup_key,
#        value   => $request,
#    );
#    $cache_params{max_age} = $params{max_age} + time()
#        if $cache_params{max_age};
#    $cache = Games::Lacuna::Task::Cache->new(
#        %cache_params
#    );
#    $storage->delete($lookup_key);
#    $storage->store($lookup_key => $cache);
#    
#    return $request;
#} 

no Moose::Role;
1;
