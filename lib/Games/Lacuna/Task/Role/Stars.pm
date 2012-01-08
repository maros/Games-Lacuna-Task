package Games::Lacuna::Task::Role::Stars;

use 5.010;
use Moose::Role;

use List::Util qw(max min);

use Games::Lacuna::Task::Utils qw(normalize_name distance);

use LWP::Simple;
use Text::CSV;

our $MAX_STAR_CACHE_AGE = 60*60*24*31*3; # Three months

after 'BUILD' => sub {
    my ($self) = @_;
    
    my ($star_count) = $self->client->storage->selectrow_array('SELECT COUNT(1) FROM star');
    
    if ($star_count == 0) {
        $self->fetch_all_stars();
    }
};

sub fetch_all_stars {
    my ($self) = @_;
    
    my $server = $self->client->client->uri;
    return
        unless $server =~ /^https?:\/\/([^.]+)\./;
    
    # Fetch starmap from server
    my $starmap_uri = 'http://'.$1.'.lacunaexpanse.com.s3.amazonaws.com/stars.csv';
    
    $self->log('info',"Fetching star map from %s. This will only happen once and might take a while.",$starmap_uri);
    my $content = get($starmap_uri);
    
    # Create temp table
    $self->storage_do('CREATE TEMPORARY TABLE temporary_star (id INTEGER NOT NULL)');
    
    # Prepare sql statements
    my $sth_check  = $self->storage_prepare('SELECT last_checked, probed FROM star WHERE id = ?');
    my $sth_insert = $self->storage_prepare('INSERT INTO star (id,x,y,name,zone,last_checked,probed) VALUES (?,?,?,?,?,?,?)');
    my $sth_temp   = $self->storage_prepare('INSERT INTO temporary_star (id) VALUES (?)');
    
    # Parse star map
    $self->log('debug',"Parsing new star map");
    my $csv = Text::CSV->new ();
    open my $fh, "<:encoding(utf8)", \$content;
    $csv->column_names( $csv->getline($fh) );
    
    # Process star map
    my $count = 0;
    while( my $row = $csv->getline_hr( $fh ) ){
        $count++;
        $sth_check->execute($row->{id});
        my ($last_checked,$probed) = $sth_check->fetchrow_array();
        $sth_check->finish();
        
        $sth_temp->execute($row->{id});
        
        $sth_insert->execute(
            $row->{id},
            $row->{x},
            $row->{y},
            $row->{name},
            $row->{zone},
            $last_checked,
            $probed,
        );
        
        $self->log('debug',"Importing %i stars",$count)
            if $count % 500 == 0;
    }
    $self->log('debug',"Finished imporing %i stars",$count);
    
    # Cleanup star table
    $self->storage_do('DELETE FROM star WHERE id NOT IN (SELECT id FROM temporary_star)');
    $self->storage_do('DELETE FROM body WHERE star NOT IN (SELECT id FROM star)');
    $self->storage_do('DROP TABLE temporary_star');
    
    return;
}

sub _get_body_cache_for_star {
    my ($self,$star_id,$star_data) = @_;
    
    return
        unless defined $star_id;
    
    my $sth = $self->storage_prepare('SELECT 
            body.id, 
            body.star,
            body.x,
            body.y,
            body.orbit,
            body.size,
            body.name,
            body.type,
            body.water,
            body.ore,
            body.empire,
            body.last_excavated,
            empire.id AS empire_id,
            empire.name AS empire_name,
            empire.alignment AS empire_alignment,
            empire.is_isolationist AS empire_is_isolationist
        FROM body
        LEFT JOIN empire ON (empire.id = body.empire)
        WHERE body.star = ?'
    );
    
    $sth->execute($star_data->{id});
    
    my @bodies;
    while (my $body = $sth->fetchrow_hashref) {
        push (@bodies,$self->_inflate_body($body,$star_data));
    }
    
    return @bodies;
}

sub _get_star_cache {
    my ($self,$query,@params) = @_;
    
    return
        unless defined $query;
    
    # Get star from cache
    my $star_cache = $self->client->storage->selectrow_hashref('SELECT 
            star.id,
            star.x,
            star.y,
            star.name,
            star.zone,
            star.last_checked,
            star.probed
        FROM star
        WHERE '.$query,
        {},
        @params
    );
    
    return
        unless defined $star_cache;
    
    return $self->_inflate_star($star_cache)
}

sub _inflate_star {
    my ($self,$star_cache) = @_;
    
    # Build star data
    my $star_data = {
        (map { $_ => $star_cache->{$_} } qw(id x y zone name probed last_checked)),
        cache_ok    => 0,
    };
    
    # Star was not checked yet
    return $star_data
        unless defined $star_cache->{last_checked};
    
    # Get cache status
    $star_data->{cache_ok} = ($star_cache->{last_checked} > (time() - $MAX_STAR_CACHE_AGE)) ? 1:0;
    
    # We have no bodies and cache seems to be valid
    return $star_data
        if $star_data->{cache_ok} == 1 && $star_data->{probed} == 0;
    
    # Get Bodies from cache
    my @bodies = $self->_get_body_cache_for_star($star_data->{id},$star_data);
    
    # Bodies ok
    if (scalar @bodies) {
        $star_data->{bodies} = \@bodies
    # Bodies missing 
    } else {
        warn "FALLBACK ON BODY: SHOULD NOT HAPPEN";
        $star_data = $self->_get_star_api($star_data->{id},$star_data->{x},$star_data->{y});
    }
    
    return $star_data;
}

sub _inflate_body {
    my ($self,$body,$star_data) = @_;
    
    return
        unless defined $body;
    
    $star_data ||= {
        star_id     => $star_data->{id},
        star_name   => $star_data->{name},
        zone        => $star_data->{zone},
    };
    
     my $body_data = {
        (map { $_ => $body->{$_} } qw(id x y orbit name type water size last_excavated)),
        ore         => $Games::Lacuna::Task::Client::JSON->decode($body->{ore}), 
        %{$star_data},
    };
    
    if ($body->{empire_id}) {
        $body_data->{empire} = {
            alignment       => $body->{empire_alignment},
            is_isolationist => $body->{empire_is_isolationist},
            name            => $body->{empire_name},
            id              => $body->{empire_id},
        };
    }

    return $body_data;
}

sub _get_body_cache {
    my ($self,$query,@params) = @_;
    
    return
        unless defined $query;
    
    my $body = $self->client->storage->fetchrow_array('SELECT 
            body.id, 
            body.star,
            body.x,
            body.y,
            body.orbit,
            body.size
            body.name,
            body.type,
            body.water
            body.ore
            body.empire
            body.last_excavated,
            star.id AS star_id,
            star.name AS star_name,
            star.zone AS zone,
            star.last_checked,
            star.probed,
            empire.id AS empire_id,
            empire.name AS empire_name,
            empire.alignment AS empire_alignment,
            empire.is_isolationist AS empire_is_isolationist
        FROM body
        INNER JOIN star ON (star.id = body.star)
        LEFT JOIN empire ON (empire.id = body.empire)
        WHERE '.$query,
        {},
        @params
    );
    
    return $self->_inflate_body($body);
}

sub get_body_by_id {
    my ($self,$id) = @_;
    
    return
        unless defined $id
        && $id =~ m/^\d+$/;
    
    return $self->_get_body_cache('body.id = ?',$id);
}

sub get_body_by_name {
    my ($self,$name) = @_;
    
    return
        unless defined $name;
    
    my $body_data = $self->_get_body_cache('body.name = ?',$name);
    
    return $body_data
        if $body_data;
        
    return $self->_get_body_cache('body.normalized_name = ?',normalize_name($name));
}

sub get_body_by_xy {
    my ($self,$x,$y) = @_;
    
    return
        unless defined $x
        && defined $y
        && $x =~ m/^-?\d+$/
        && $y =~ m/^-?\d+$/;
    
    $self->_get_body_cache('body.x = ? AND body.y = ?',$x,$y);
    
    my ($star_data) = $self->list_stars(
        x       => $x,
        y       => $y,
        limit   => 1,
        distance=> 1,
    );
    
    foreach my $body_data (@{$star_data->{bodies}}) {
        return $body_data
            if $body_data->{x} == $x
            && $body_data->{y} == $y;
    }
    
    return;
}

sub _find_star {
    my ($self,$query,@params) = @_;
    
    return
        unless defined $query;
    
    # Query starmap/cache
    my $star_data = $self->_get_star_cache($query,@params);
    
    # No hit for query
    return
        unless $star_data;
    
    # Cache is valid
    return $star_data
        if $star_data->{cache_ok};
    return $self->_get_star_api($star_data->{id},$star_data->{x},$star_data->{y});
}

sub _get_star_api {
    my ($self,$star_id,$x,$y) = @_;
    
    my $step = int($Games::Lacuna::Task::Constants::MAX_MAP_QUERY / 2);
    
    # Fetch x and y unless given
    unless (defined $x && defined $y) {
        ($x,$y) = $self->client->storage->selectrow_array('SELECT x,y FROM star WHERE id = ?',{},$star_id);
    }
    
    return
        unless defined $x && defined $y;
    
    # Get area
    my $min_x = $x - $step;
    my $min_y = $y - $step;
    my $max_x = $x + $step;
    my $max_y = $y + $step;
    
    # Get star from api
    my $star_list = $self->_get_area_api_by_xy($min_x,$min_y,$max_x,$max_y);
    
    # Find star in list
    foreach my $element (@{$star_list}) {
        return $element
            if $element->{id} == $star_id;
    }
    
    return;
}


sub get_star_by_name {
    my ($self,$name) = @_;
    
    return
        unless defined $name;
    
    return $self->_find_star('star.name = ?',$name);
}

sub get_star_by_xy {
    my ($self,$x,$y) = @_;
    
    return
        unless defined $x
        && defined $y
        && $x =~ m/^-?\d+$/
        && $y =~ m/^-?\d+$/;
    
    return $self->_find_star('star.x = ? AND star.y = ?',$x,$y);
}

sub get_star {
    my ($self,$star_id) = @_;
    
    return
        unless defined $star_id && $star_id =~ m/^\d+$/;
    
    return $self->_find_star('star.id = ?',$star_id);
}

sub _get_area_api_by_xy {
    my ($self,$min_x,$min_y,$max_x,$max_y) = @_;
    
    my $bounds = $self->get_environment('star_map_size');
    return
        if $bounds->{x}[0] >= $max_x || $bounds->{x}[1] <= $min_x;
    return
        if $bounds->{y}[0] >= $max_y || $bounds->{y}[1] <= $min_y;
    
    $min_x = max($min_x,$bounds->{x}[0]);
    $max_x = min($max_x,$bounds->{x}[1]);
    $min_y = max($min_y,$bounds->{y}[0]);
    $max_y = min($max_y,$bounds->{y}[1]);
    
    # Fetch from api
    my $star_info = $self->request(
        object  => $self->build_object('Map'),
        params  => [ $min_x,$min_y,$max_x,$max_y ],
        method  => 'get_stars',
    );
    
    # Loop all stars in area
    my @return;
    foreach my $star_data (@{$star_info->{stars}}) {
        # Set cache controll flags
        $star_data->{last_checked} = time();
        $star_data->{cache_ok} = 1;
        
        # Check if system is probed or not
        if (defined $star_data->{bodies}
            && scalar(@{$star_data->{bodies}}) > 0) {
            $star_data->{probed} = 1;
            $self->set_star_cache($star_data);
        } else {
            $star_data->{probed} = 0;
            $self->storage_do('UPDATE star SET probed = 0, last_checked = ? WHERE id = ?',{},time,$star_data->{id});
        }
        
        push(@return,$star_data);
    }
    
    return \@return;
}

sub set_star_cache {
    my ($self,$star_data) = @_;
    
    my $star_id = $star_data->{id};
    
    return
        unless defined $star_id;
    
    my $storage = $self->client->storage;
    
    # Update star cache
    $self->storage_do(
        'UPDATE star SET probed = ?, last_checked = ?, name = ? WHERE id = ?',
        $star_data->{probed},
        $star_data->{last_checked},
        $star_data->{name},
        $star_id
    );
    
    return
        unless defined $star_data->{bodies};
    
    # Get excavate status
    my %last_excavated;
    my $sth_excavate = $self->storage_prepare('SELECT id,last_excavated FROM body WHERE star = ? AND last_excavated IS NOT NULL');
    $sth_excavate->execute($star_id);
    while (my ($body_id,$last_excavated) = $sth_excavate->fetchrow_array) {
        $last_excavated{$body_id} = $last_excavated;
    }
    
    # Remove all bodies
    $self->storage_do('DELETE FROM body WHERE star = ?',$star_id);
    
    # Insert or update empire
    my $sth_empire = $self->storage_prepare('INSERT OR REPLACE INTO empire
        (id,name,normalized_name,alignment,is_isolationist) 
        VALUES
        (?,?,?,?,?)');
    
    # Insert new bodies
    my $sth_insert = $self->storage_prepare('INSERT INTO body 
        (id,star,x,y,orbit,size,name,normalized_name,type,water,ore,empire,last_excavated) 
        VALUES
        (?,?,?,?,?,?,?,?,?,?,?,?,?)');
    
    # Cache bodies
    foreach my $body_data (@{$star_data->{bodies}}) {
        my $empire = $body_data->{empire} || {};
        
        $body_data->{last_excavated} = $last_excavated{$body_data->{id}};
        
        $sth_insert->execute(
            $body_data->{id},
            $star_id,
            $body_data->{x},
            $body_data->{y},
            $body_data->{orbit},
            $body_data->{size},
            $body_data->{name},
            normalize_name($body_data->{name}),
            $body_data->{type},
            $body_data->{water},
            $Games::Lacuna::Task::Client::JSON->encode($body_data->{ore}),
            $empire->{id},
            $body_data->{last_excavated},
        );
        
        if (defined $empire->{id}) {
            $sth_empire->execute(
                $empire->{id},
                $empire->{name},
                normalize_name($empire->{name}),
                $empire->{alignment},
                $empire->{is_isolationist},
            );
        }
    }
}

sub search_stars_callback {
    my ($self,$callback,%params) = @_;
    
    my @sql_where;
    my @sql_params;
    my @sql_extra;
    my @sql_fields = qw(star.id star.x star.y star.name star.zone star.last_checked star.probed);
    
    # Order by distance
    if (defined $params{distance}
        && defined $params{x}
        && defined $params{y}) {
        push(@sql_fields,'distance_func(star.x,star.y,?,?) AS distance');
        push(@sql_params,$params{x}+0,$params{y}+0);
        # Does not seem to work for some stronge reason
        #if (defined $params{min_distance}) {
        #    push(@sql_where,'distance >= ?');
        #    push(@sql_params,$params{min_distance}+0);
        #}
        #if (defined $params{max_distance}) {
        #    push(@sql_where,'distance <= ?');
        #    push(@sql_params,$params{max_distance}+0);
        #}
        push(@sql_extra," ORDER BY distance ".($params{distance} ? 'ASC':'DESC'));
    }
    # Only probed/unprobed or unknown
    if (defined $params{probed}) {
        push(@sql_where,'(star.last_checked > ? OR star.probed = ? OR star.probed IS NULL)');
        push(@sql_params,(time - $MAX_STAR_CACHE_AGE),$params{probed});
    }
    # Zone
    if (defined $params{zone}) {
        push(@sql_where,'star.zone = ?');
        push(@sql_params,$params{zone});
    }
    ## Limit results
    #if (defined $params{limit}) {
    #    push(@sql_extra," LIMIT ?");
    #    push(@sql_params,$params{limit});
    #}
    
    # Build sql
    my $sql = "SELECT ".join(',',@sql_fields). " FROM star ";
    $sql .= ' WHERE '.join(' AND ',@sql_where)
        if scalar @sql_where;
    $sql .= join(' ',@sql_extra);
    
    warn "RUN $sql : ".join(',',@sql_params);
    
    my $sth = $self->storage_prepare($sql);
    $sth->execute(@sql_params)
        or $self->abort('Could not execute SQL command "%s": %s',$sql,$sth->errstr);
    
    my $count = 0;
    # Loop all results
    while (my $star_cache = $sth->fetchrow_hashref) {
        # Filter distance
        next
            if defined $params{min_distance} && $star_cache->{distance} < $params{min_distance};
        next
            if defined $params{max_distance} && $star_cache->{distance} > $params{max_distance};
        
        # Inflate star data
        my $star_data;
        if (defined $star_cache->{last_checked} 
            && $star_cache->{last_checked} > (time - $MAX_STAR_CACHE_AGE)) {
            $star_data = $self->_inflate_star($star_cache);
        } else {
            $star_data = $self->_get_star_api($star_cache->{id},$star_cache->{x},$star_cache->{y});
        }
        
        # Check definitve probed status
        next
            if (defined $params{probed} && $star_data->{probed} != $params{probed});
        
        # Set distance
        $star_data->{distance} = $star_cache->{distance}
            if defined $star_cache->{distance};
        
        $count ++;
        
        # Run callback
        my $return = $callback->($star_data);
        
        last
            unless $return;
        last
            if defined $params{limit} && $count >= $params{limit};
    }
    
    $sth->finish();
    
    return;
}

sub set_body_excavated {
    my ($self,$body_id,$timestamp) = @_;
    
    $timestamp ||= time();
    $self->storage_do('UPDATE body SET last_excavated = ? WHERE id = ?',$timestamp,$body_id);
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