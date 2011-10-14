package Games::Lacuna::Task::Action::StarCache;

use 5.010;
use List::Util qw(max min);

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars);

sub description {
    return q[This task builds a star cache and can help to reduce the number of api calls made by various tasks];
}

our $MAX_SIZE = 30;
our $BOUNDS;

has 'coordinate' => (
    is          => 'ro',
    isa         => 'Lacuna::Task::Type::Coordinate',
    documentation=> q[Coordinates for query center],
    coerce      => 1,
    lazy_build  => 1,
);

has 'skip' => (
    is          => 'ro',
    isa         => 'Int',
    default     => 1,
    documentation=> q[Skip firt N-queries],
);

has 'count' => (
    is          => 'ro',
    isa         => 'Int',
    default     => 20,
    documentation=> q[Number of queries to be cached],
);

sub _build_coordinate {
    my ($self) = @_;
    
    my $home_planet = $self->home_planet_id();
    my $home_planet_data = $self->my_body_status($home_planet);
    
    return [$home_planet_data->{x},$home_planet_data->{y}];
}

sub run {
    my ($self) = @_;
    
    my @pos = (0,0);
    my @vector = (-1,0);
    my $segment_length = 1;
    my $segment_passed = 0;
    
    if ($self->skip <= 1) {
        $self->get_star_area(0,0);
    }
    for my $round (2..$self->count) {
        $pos[$_] += $vector[$_] for (0..1);
        $segment_passed++;
        
        if ($round > $self->skip) {
            $self->get_star_area(@pos);
        }
        
        if ($segment_passed == $segment_length) {
            $segment_passed = 0;
            my $buffer = $vector[0];
            $vector[0] = $vector[1] * -1;
            $vector[1] = $buffer;
            $segment_length++
                if $vector[1] == 0;
        }
    }
}

sub get_star_area {
    my ($self,$x,$y) = @_;
    
    my ($cx,$cy) = ($x + $self->coordinate->[0],$y + $self->coordinate->[1]);
    my ($min_x,$min_y) = ( $x * $MAX_SIZE + $cx , $y * $MAX_SIZE + $cy);
    my ($max_x,$max_y) = ( ($x+1) * $MAX_SIZE + $cx , ($y+1) * $MAX_SIZE + $cy);
    
    if (defined $BOUNDS) {
        return
            if $BOUNDS->{x}[0] >= $max_x || $BOUNDS->{x}[1] <= $min_x;
        return
            if $BOUNDS->{y}[0] >= $max_y || $BOUNDS->{y}[1] <= $min_y;
        $min_x = max($min_x,$BOUNDS->{x}[0]);
        $max_x = min($max_x,$BOUNDS->{x}[1]);
        $min_y = max($min_y,$BOUNDS->{y}[0]);
        $max_y = min($max_y,$BOUNDS->{y}[1]);
    }
    
    my $star_info = $self->request(
        object  => $self->build_object('Map'),
        params  => [ $min_x,$min_y,$max_x,$max_y ],
        method  => 'get_stars',
    );
    
    unless (defined $BOUNDS) {
        $BOUNDS = $star_info->{status}{server}{star_map_size};
    }
    
    foreach my $star_data (@{$star_info->{stars}}) {
        my $star_id = $star_data->{id};
        if (defined $star_data->{bodies}
            && scalar(@{$star_data->{bodies}}) > 0) {
            $star_data->{probed} = 1;
        } else {
            my $star_cache = $self->get_star_cache($star_id);
            $star_data->{bodies} = $star_cache->{bodies}
                if defined $star_cache && defined $star_cache->{bodies};
            $star_data->{probed} = 0;
        }
        $self->set_star_cache($star_data);
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
