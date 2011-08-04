package Games::Lacuna::Task::Role::Stars;

use 5.010;
use Moose::Role;

use LWP::Simple;
use Text::CSV;


has 'stars' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    lazy_build      => 1,
    traits          => ['NoIntrospection'],
    documentation   => q[List of all known stars],
);

has 'stars_cache' => (
    is              => 'rw',
    isa             => 'HashRef',
    default         => sub { return{} },
    traits          => ['NoIntrospection'],
    documentation   => q[Temporary cache for star data],
);

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
        max_age => (60*60*24*31*2), # Cache two months
    );
    
    return \@stars;
}

sub find_star_by_xy {
    my ($self,$x,$y) = @_;
    
    foreach my $star (@{$self->stars}) {
        return $star->{id}
            if $star->{x} == $x
            && $star->{y} == $y;
    }
}

sub get_star {
    my ($self,$star) = @_;
    
    return
        unless $star && $star =~ m/^\d+$/;
    
    my $star_cache;
    # Get from runtime cache
    $star_cache = $self->stars_cache->{$star};
    # Get from local cache
    $star_cache ||= $self->lookup_cache('stars/'.$star);
    # Get from api
    $star_cache ||= $self->check_star($star);
    
    return $star_cache;
}

sub is_probed_star {
    my ($self,$star) = @_;
    
    return
        unless $star && $star =~ m/^\d+$/;
    
    my $star_data = $self->get_star($star);
    
    return 1 
        if defined $star_data->{bodies}
        && scalar @{$star_data->{bodies}} > 0;
    return 0;
}

sub check_star {
    my ($self,$star) = @_;
    
    return
        unless $star && $star =~ m/^\d+$/;
    
    return $self->stars_cache->{$star}
        if defined $self->stars_cache->{$star};
    
    my $star_cache_key = 'stars/'.$star;
    
    my $star_info = $self->request(
        object  => $self->build_object('Map'),
        params  => [ $star ],
        method  => 'get_star',
    );
    my $star_data = $star_info->{star};
    
    # Write to local cache
    $self->write_cache(
        key     => $star_cache_key,
        value   => $star_data,
        max_age => (60*60*24*7*4), # Cache four weeks
    );
    
    # Write to runtime cache
    $self->stars_cache->{$star} = $star_data;
    
    return $star_data;
}

sub stars_by_distance {
    my ($self,$x,$y,$inverse) = @_;
    
    return 
        unless defined $x && defined $y;
    
    $inverse //= 0;
    
    my $stars = $self->stars;
    
    my @star_distance;
    foreach my $star (@{$stars}) {
        my $dist = sqrt( ($star->{x} - $x)**2 + ($star->{y} - $y)**2 );
        push(@star_distance,[$dist,$star]);
    }
    
    return 
        map { $_->[1] } 
        sort { $inverse ? ($b->[0] <=> $a->[0]):($a->[0] <=> $b->[0]) } 
        @star_distance;
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

=head2 lookup_star

 $star_data = $self->check_star($star_id);

Fetches star data from the API for the given star id

=head2 get_star

 $star_data = $self->check_star($star_id);

Like L<check_star> but queries local caches first

=head2 is_probed_star

 my $bool = $self->is_probed_star($star_id);

Check if a star is probed or not

=head2 stars_by_distance

 my @stars = $self->stars_by_distance($x,$y,$inverse)

Returns a list of stars ordered by distance to the given point

=head2 find_star_by_xy

 my $star_data = $self->find_star_by_xy($x,$y)

Returns a star for the given coordinates

=head2 find_body_by_name

 my $body_data = $self->find_body_by_name($body_name)

Returns body data for the given name

=head2 find_body_by_xy

 my $body_data = $self->find_body_by_name($x,$y)

Returns body data for the given coordinates

=head2 stars

List of all stars on the current game server

=cut