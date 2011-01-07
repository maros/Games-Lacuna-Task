package Games::Lacuna::Task::Role::Stars;

use 5.010;
use Moose::Role;

use LWP::Simple;
use Text::CSV;


has 'stars' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    lazy_build      => 1,
    documentation   => q[List of all known stars],
);

has 'probed_stars' => (
    is              => 'rw',
    isa             => 'HashRef[Int]',
    lazy_build      => 1,
    documentation   => q[Cache of all probed stars],
);

has 'unprobed_stars' => (
    is          => 'rw',
    isa         => 'HashRef[Int]',
    lazy_build  => 1,
    documentation   => q[Cache of all unprobed stars],
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

sub add_probed_star {
    my ($self,$star) = @_;
    return
        unless $star;
    $self->probed_stars->{$star} = 1;
    delete $self->unprobed_stars->{$star};
}

sub add_unprobed_star {
    my ($self,$star) = @_;
    return
        unless $star;
    $self->unprobed_stars->{$star} = 1;
}

sub is_probed_star {
    my ($self,$star) = @_;
    
    return
        unless $star;
    return $star ~~ $self->probed_stars;
}

sub is_unprobed_star {
    my ($self,$star) = @_;
    
    return
        unless $star;
    return $star ~~ $self->unprobed_stars;
}

sub save_unprobed_stars {
    my ($self) = @_;
    
    $self->write_cache(
        key     => 'stars/unprobed',
        value   => $self->unprobed_stars,
        max_age => (60*60*24*7*2), # Cache two weeks
    );
}

sub save_probed_stars {
    my ($self) = @_;
    
    $self->write_cache(
        key     => 'stars/probed',
        value   => $self->probed_stars,
        max_age => (60*60*24*7*2), # Cache two weeks
    );
}

sub _build_probed_stars {
    my ($self) = @_;
    
    my $probed_stars = $self->lookup_cache('stars/probed');
    $probed_stars ||= {};
    return $probed_stars;
}

sub _build_unprobed_stars {
    my ($self) = @_;
    
    my $unprobed_stars = $self->lookup_cache('stars/unprobed');
    $unprobed_stars ||= {};
    return $unprobed_stars;
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
