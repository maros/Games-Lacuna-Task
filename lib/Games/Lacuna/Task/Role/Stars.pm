package Games::Lacuna::Task::Role::Stars;

use 5.010;
use Moose::Role;

use List::Util qw(max min);

use Games::Lacuna::Task::Utils qw(normalize_name distance);

use LWP::Simple;
use Text::CSV;

our %STAR_CACHE;

has 'stars' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    lazy_build      => 1,
    traits          => ['NoIntrospection','NoGetopt'],
    documentation   => q[List of all known stars],
);

has 'map_bounds' => (
    is              => 'rw',
    isa             => 'HashRef',
    lazy_build      => 1,
    traits          => ['NoIntrospection','NoGetopt'],
    documentation   => q[Map bounds],
);

sub _build_map_bounds {
    my ($self) = @_;
    
    my $server = $self->lookup_cache('server');
    return $server->{star_map_size};
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
    
    $self->log('debug',"Fetching star map from %s. This might take a while.",$starmap_uri);
    
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
        max_age => (60*60*24*31*3), # Cache three months
    );
    
    return \@stars;
}

sub find_body_by_id {
    my ($self,$id) = @_;
    
    return
        unless defined $id
        && $id =~ m/^\d+$/;
    
    my $cache = $self->client->storage->search({ id => { REGEXP => 'stars/[[:digit:]]' }});
    while( my $block = $cache->next ) {
        foreach my $item ( @$block ) {
            foreach my $body (@{$item->value->{bodies}}) {
                return $body
                    if $body->{id} == $id;
            }
        }
    }
    return;
}


sub find_body_by_name {
    my ($self,$name) = @_;
    
    return
        unless defined $name;
    $name = normalize_name($name);
    
    my $cache = $self->client->storage->search({ id => { REGEXP => 'stars/[[:digit:]]' }});
    while( my $block = $cache->next ) {
        foreach my $item ( @$block ) {
            foreach my $body (@{$item->value->{bodies}}) {
                return $body
                    if normalize_name($body->{name}) eq $name;
            }
        }
    }
    return;
}


sub find_body_by_xy {
    my ($self,$x,$y) = @_;
    
    return
        unless defined $x
        && defined $y
        && $x =~ m/^-?\d+$/
        && $y =~ m/^-?\d+$/;
    
    my $counter = 0;
    my @stars = $self->stars_by_distance($x,$y);
    
    foreach my $star (@stars) {
        $counter ++;
        my $star_data = $self->get_star($star->{id});
        foreach my $body (@{$star_data->{bodies}}) {
            return $body
                if $body->{x} == $x
                && $body->{y} == $y;
        }
        return 
            if $counter > 3;
    }
    return;
}

sub find_star_by_name {
    my ($self,$name) = @_;
    
    return
        unless defined $name;
    
    foreach my $star (@{$self->stars}) {
        return $star->{id}
            if $star->{name} eq $name;;
    }
}

sub find_star_by_xy {
    my ($self,$x,$y) = @_;
    
    return
        unless defined $x
        && defined $y
        && $x =~ m/^-?\d+$/
        && $y =~ m/^-?\d+$/;
    
    foreach my $star (@{$self->stars}) {
        return $star->{id}
            if $star->{x} == $x
            && $star->{y} == $y;
    }
}

sub is_probed_star {
    my ($self,$star_id) = @_;
    
    return
        unless defined $star_id && $star_id =~ m/^\d+$/;
    
    my $star_data = $self->get_star($star_id);
    
    return $star_data->{probed}
        if defined $star_data->{probed};
    
    return 1 
        if defined $star_data->{bodies}
        && scalar @{$star_data->{bodies}} > 0;
    
    return 0;
}

sub get_star {
    my ($self,$star_id) = @_;
    
    my $star_data;
    
    return
        unless defined $star_id && $star_id =~ m/^\d+$/;
    
    # Get from cache
    $star_data = $self->get_star_cache($star_id);
    return $star_data
        if defined $star_data;
    
    # Get from api
    $star_data = $self->get_star_api_area_by_id($star_id);
    
    return $star_data;
}

sub get_star_cache {
    my ($self,$star) = @_;
    
    return
        unless defined $star && $star =~ m/^\d+$/;
    
    # Get from runtime cache
    return $STAR_CACHE{$star}
        if defined $STAR_CACHE{$star};
    
    # Get from local cache
    my $star_data = $self->lookup_cache('stars/'.$star);
    
    return
        unless defined $star_data
        && defined $star_data->{id};
    
    $star_data->{probed} //= (defined $star_data->{bodies}
        && scalar @{$star_data->{bodies}} > 0) ? 1:0;
    
    $STAR_CACHE{$star} = $star_data;
    
    return $star_data;
}

sub get_star_api_area_by_id {
    my ($self,$star_id) = @_;
    
    return
        unless defined $star_id && $star_id =~ m/^\d+$/;
    
    my $stars = $self->stars;
    my ($x,$y,$min_x,$min_y,$max_x,$max_y,$star_return);
    
    foreach my $star (@{$stars}) {
        if ($star->{id} == $star_id) {
            $x = $star->{x};
            $y = $star->{y};
            last;
        }
    }
    
    return
        unless defined $x && defined $y;
    
    no warnings 'once';
    my $step = int($Games::Lacuna::Task::Constants::MAX_MAP_QUERY / 2);
    
    $min_x = $x - $step;
    $min_y = $y - $step;
    $max_x = $x + $step;
    $max_y = $y + $step;
    
    my $star_list = $self->get_star_api_area_by_xy($min_x,$min_y,$max_x,$max_y);
    
    return 
        unless $star_list;
    
    foreach my $star_data (@{$star_list}) {
        return $star_data
            if $star_id == $star_data->{id};
    }
}


sub get_star_api_area_by_xy {
    my ($self,$min_x,$min_y,$max_x,$max_y) = @_;
    
    my $bounds = $self->map_bounds;
    return
        if $bounds->{x}[0] >= $max_x || $bounds->{x}[1] <= $min_x;
    return
        if $bounds->{y}[0] >= $max_y || $bounds->{y}[1] <= $min_y;
    
    $min_x = max($min_x,$bounds->{x}[0]);
    $max_x = min($max_x,$bounds->{x}[1]);
    $min_y = max($min_y,$bounds->{y}[0]);
    $max_y = min($max_y,$bounds->{y}[1]);
    
    my $star_info = $self->request(
        object  => $self->build_object('Map'),
        params  => [ $min_x,$min_y,$max_x,$max_y ],
        method  => 'get_stars',
    );
    
    my @return;
    foreach my $star_data (@{$star_info->{stars}}) {
        if (defined $star_data->{bodies}
            && scalar(@{$star_data->{bodies}}) > 0) {
            $star_data->{probed} = 1;
        } else {
            my $star_cache = $self->get_star_cache($star_data->{id});
            $star_data->{bodies} = $star_cache->{bodies}
                if defined $star_cache && defined $star_cache->{bodies};
            $star_data->{probed} = 0;
        }
        $self->set_star_cache($star_data);
        
        push(@return,$star_data);
    }
    
    return \@return;
}

sub get_star_api_single {
    my ($self,$star_id) = @_;
    
    return
        unless defined $star_id && $star_id =~ m/^\d+$/;
    
    my $star_info = $self->request(
        object  => $self->build_object('Map'),
        params  => [ $star_id ],
        method  => 'get_star',
    );
    
    my $star_data = $star_info->{star};
    
    if (defined $star_data->{bodies}
        && scalar(@{$star_data->{bodies}}) > 0) {
        $star_data->{probed} = 1;
    } else {
        $star_data->{probed} = 0;
    }
    
    # Write to cache
    $self->set_star_cache($star_data);
    
    return $star_data;
}

sub set_star_cache {
    my ($self,$star_data) = @_;
    
    my $star_id = $star_data->{id};
    
    return
        unless defined $star_id;
    
    # Keep body information from previous caches
    unless (defined $star_data->{bodies}
        && scalar(@{$star_data->{bodies}}) > 0) {
        my $star_cache = $self->get_star_cache($star_id);
        $star_data->{bodies} = $star_cache->{bodies}
            if defined $star_cache->{bodies}
            && scalar(@{$star_data->{bodies}}) > 0;
    }
    
    # Write to local cache
    $self->write_cache(
        key     => 'stars/'.$star_id,
        value   => $star_data,
        max_age => (60*60*24*7*8), # Cache eight weeks
    );
    
    # Write to runtime cache
    $STAR_CACHE{$star_id} = $star_data;
}

sub stars_by_distance {
    my ($self,$x,$y,$callback) = @_;
    
    return 
        unless defined $x && defined $y;
    
    my $stars = $self->stars;
    
    my @star_distance;
    foreach my $star (@{$stars}) {
        my $dist = distance($star->{x},$star->{y},$x,$y);
        push(@star_distance,[$dist,$star]);
    }
    
    my @return;
    foreach my $star (sort { $a->[0] <=> $b->[0] } @star_distance) {
        if (defined $callback) {
            next
                unless $callback->($star->[1],$star->[0]);
        }
        push(@return,$star->[1])
    }
    
    return @return;
}

no Moose::Role;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Role::Stars - Astronomy helper methods

=head1 SYNOPSIS

    package Games::Lacuna::Task::Action::MyTask;
    use Moose;
    extends qw(Games::Lacuna::Task::Action);
    with qw(Games::Lacuna::Task::Role::Stars);
    
=head1 DESCRIPTION

This role provides astronomy-related helper methods.

=head1 METHODS

=head2 get_star

 $star_data = $self->get_star($star_id);

Fetches star data from the API or local cache for the given star id

=head2 get_star_api

 $star_data = $self->get_star_api($star_id);

Fetches star data from the API for the given star id

=head2 get_star_cache

 $star_data = $self->get_star_cache($star_id);

Fetches star data from the local cache for the given star id

=head2 is_probed_star

 my $bool = $self->is_probed_star($star_id);

Check if a star is probed or not

=head2 stars_by_distance

 my @stars = $self->stars_by_distance($x,$y,$callback)

Returns a list of stars ordered by distance to the given point. Optionally
$callback can be added to filter the star list.

=head2 find_star_by_xy

 my $star_id = $self->find_star_by_xy($x,$y)

Returns a star id for the given coordinates

=head2 find_star_by_name

 my $star_id = $self->find_star_by_name($name)

Returns a star id for the given name

=head2 find_body_by_id

 my $body_data = $self->find_body_by_id($body_id)

Returns body data for the given id

=head2 find_body_by_name

 my $body_data = $self->find_body_by_name($body_name)

Returns body data for the given name

=head2 find_body_by_xy

 my $body_data = $self->find_body_by_name($x,$y)

Returns body data for the given coordinates

=head2 stars

List of all stars on the current game server

=cut