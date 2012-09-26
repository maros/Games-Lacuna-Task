package Games::Lacuna::Task::Role::Storage;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;

use Games::Lacuna::Client::Types qw(ore_types food_types is_food_type is_ore_type);

sub resource_type {
    my ($self,$type) = @_;
    
    given ($type) {
        when ([qw(waste water ore food energy happiness essentia)]) {
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
        # 
        when ([ ore_types(),food_types() ]) {
            my $resources = $self->resources_stored($planet_stats);
            return $resources->{$resource}
                if defined $resources && defined $resources->{$resource};
        }
    }
    
    return;
}

sub resources_stored {
    my ($self,$planet_stats) = @_;
    
    my $cache_key = 'body/'.$planet_stats->{id}.'/resources';
    my $stored = $self->get_cache($cache_key);
    return $stored
        if defined $stored;
    
    # TODO: better via PCC
    
    # Get trade ministry
    my $trade_object = $self->get_building_object($planet_stats->{id},'Trade');
    return
        unless $trade_object;
    my $stored_response = $self->request(
        object  => $trade_object,
        method  => 'get_stored_resources',
    );
    
    $self->set_cache(
        key     => $cache_key,
        value   => $stored_response->{resources},
        max_age => (60*60),
    );
    
    return $stored_response->{resources};
}

sub plans_stored {
    my ($self,$planet_id) = @_;
    
    $planet_id = $planet_id->{id}
        if ref($planet_id) eq 'HASH';
    
    my $cache_key = 'body/'.$planet_id.'/plans';
    my $plans = $self->get_cache($cache_key);
    return $plans
        if defined $plans;
    
    my $command = $self->find_building($planet_id,'PlanetaryCommand');
    $command ||= $self->find_building($planet_id,'StationCommand');
    
    my $command_object = $self->build_object($command);
    my $response = $self->request(
        object  => $command_object,
        method  => 'view_plans',
    );
    $plans = $response->{plans};
    
    $self->set_cache(
        key     => $cache_key,
        value   => $plans,
        cache   => (60*60),
    );
    
    return $plans;
}

sub glyphs_stored {
    my ($self,$planet_stats) = @_;
    
    my $cache_key = 'body/'.$planet_stats->{id}.'/glyphs';
    my $stored = $self->get_cache($cache_key);
    return $stored
        if defined $stored;
    
    # Get trade ministry
    my $trade_object = $self->get_building_object($planet_stats->{id},'Trade');
    return
        unless $trade_object;
    my $stored_response = $self->request(
        object  => $trade_object,
        method  => 'get_glyph_summary',
    );
    
    $stored = { map { $_ => 0 } ore_types() };
    foreach my $element (@{$stored_response->{glyphs}}) {
        $stored->{$element->{type}} = $element->{quantity};
    }
    
    $self->set_cache(
        key     => $cache_key,
        value   => $stored,
        max_age => (60*60),
    );
    
    return $stored;
}

sub all_glyphs_stored {
    my ($self) = @_;
    
    # Fetch total glyph count from cache
    my $all_glyphs = $self->get_cache('glyphs');
    return $all_glyphs
        if defined $all_glyphs;
    
    # Set all glyphs to zero
    $all_glyphs = { map { $_ => 0 } ore_types() };
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->my_planets) {
        my $glyph_data = $self->glyphs_stored($planet_stats);
        next 
            unless $glyph_data;
        foreach my $glyph ( ore_types() ) {
            $all_glyphs->{$glyph} += $glyph_data->{$glyph};
        }
    }
    
    # Write total glyph count to cache
    $self->set_cache(
        key     => 'glyphs',
        value   => $all_glyphs,
        max_age => (60*60*24),
    );
    
    return $all_glyphs;
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
 # $type is 'ore'

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