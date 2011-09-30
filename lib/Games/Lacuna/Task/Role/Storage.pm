package Games::Lacuna::Task::Role::Storage;

use 5.010;
use Moose::Role;

use Games::Lacuna::Client::Types qw(ore_types food_types);

sub resource_type {
    my ($self,$type) = @_;
    
    given ($type) {
        when ([qw(waste water ore food energy happiness)]) {
            return $_;
        }
        when ([ ore_types() ]) {
            return 'ore'
        }
        when ([ food_types() ]) {
            return 'food'
        }
    }
}

sub check_stored {
    my ($self,$planet_stats,$resource) = @_;
    
    given ($resource) {
        when ([qw(waste water ore food energy)]) {
            return $planet_stats->{$_.'_stored'};
        }
        when ('happiness') {
            return $planet_stats->{$_};
        }
        when ([ ore_types() ]) {
            my $ores = $self->ore_stored($planet_stats->{id});
            return $ores->{$_}
        }
        when ([ food_types() ]) {
            my $foods = $self->food_stored($planet_stats->{id});
            return $foods->{$_}
        }
    }
    return;
}

sub plans_stored {
    my ($self,$planet_id) = @_;
    
    $planet_id = $planet_id->{id}
        if ref($planet_id) eq 'HASH';
    
    my $cache_key = 'body/'.$planet_id.'/plans';
    
    my $plans = $self->lookup_cache($cache_key);
    
    return $plans
        if defined $plans;
    
    my $planetary_command = $self->find_building($planet_id,'PlanetaryCommand');
    my $planetary_command_object = $self->build_object($planetary_command);
    my $response = $self->request(
        object  => $planetary_command_object,
        method  => 'view_plans',
    );
    
    $plans = $response->{plans};
    
    $self->write_cache(
        key     => $cache_key,
        value   => $plans,
    );
    
    return $plans;
}

sub ore_stored {
    my ($self,$planet_id) = @_;
    $self->_resource_stored($planet_id,'ore','OreStorage');
}

sub food_stored {
    my ($self,$planet_id) = @_;
    $self->_resource_stored($planet_id,'food','FoodReserve');
}

sub _resource_stored {
    my ($self,$planet_id,$resource,$building_name) = @_;
    
    $planet_id = $planet_id->{id}
        if ref($planet_id) eq 'HASH';
    
    my $cache_key = 'body/'.$planet_id.'/storage/'.$resource;
    
    my $stored = $self->lookup_cache($cache_key);
    
    return $stored
        if defined $stored;
    
    my $storage_builiding = $self->find_building($planet_id,$building_name);
    
    return
        unless $storage_builiding;
    
    my $storage_builiding_object = $self->build_object($storage_builiding);
    
    my ($resource_subtype,@dump_params);
    
    my $response = $self->request(
        object  => $storage_builiding_object,
        method  => 'view',
    );
    
    $stored = $response->{lc($resource).'_stored'};
    
    $self->write_cache(
        key     => $cache_key,
        value   => $stored,
        max_age => 600,
    );
    
    return $stored;
}


no Moose::Role;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Role::Storage - Storage helper methods

=head1 SYNOPSIS

    package Games::Lacuna::Task::Action::MyTask;
    use Moose;
    extends qw(Games::Lacuna::Task::Action);
    with qw(Games::Lacuna::Task::Role::Storage);
    
=head1 DESCRIPTION

This role provides helper method to query storage buildings.

=head1 METHODS

=head2 resource_type

 my $type = $self->resource_type('magnetite');
 # $type now is 'ore'

Returns the type of the requested resource

=head2 check_stored

 my $quantity1 = $self->resource_type($planet_stats,'magnetite');
 my $quantity2 = $self->resource_type($planet_stats,'water');

Returns the stored quantity for the given resource

=head2 food_stored

 $self->food_stored($planet_id);

Returns a hashref of all stored foods

=head2 ore_stored

 $self->ore_stored($planet_id);

Returns a hashref of all stored ores

=head2 plans_stored

 $self->ore_stored($planet_id);

Returns an arrayref of all stored plans

=head2 _resource_stored

 $self->_resource_stored($planet_id,'ore','OreStorage');

Helper method to query storage building for details.

=cut