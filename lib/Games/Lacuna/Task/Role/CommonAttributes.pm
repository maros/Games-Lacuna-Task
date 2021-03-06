package Games::Lacuna::Task::Role::CommonAttributes;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;
no if $] >= 5.017004, warnings => qw(experimental::smartmatch);

use MooseX::Role::Parameterized;

parameter 'attributes' => (
    isa      => 'ArrayRef[Str]',
    required => 1,
);

role {
    my $p = shift;

    if ('orbit' ~~ $p->attributes) {
        has 'min_orbit' => (
            is              => 'rw',
            isa             => 'Int',
            lazy_build      => 1,
            documentation   => 'Min orbit. Defaults to your species min orbit',
        );
        
        has 'max_orbit' => (
            is              => 'rw',
            isa             => 'Int',
            lazy_build      => 1,
            documentation   => 'Max orbit. Defaults to your species max orbit',
        );
        
        method '_build_min_orbit' => sub{
            my ($self) = @_;
            return $self->_get_orbit->{min};
        };
        
        method '_build_max_orbit' => sub{
            my ($self) = @_;
            return $self->_get_orbit->{max};
        };
        
        method '_get_orbit' => sub{
            my ($self) = @_;
            
            my $species_stats = $self->request(
                object  => $self->build_object('Empire'),
                method  => 'view_species_stats',
            )->{species};
            
            
            $self->min_orbit($species_stats->{min_orbit})
                unless $self->meta->get_attribute('min_orbit')->has_value($self);
            $self->max_orbit($species_stats->{max_orbit})
                unless $self->meta->get_attribute('max_orbit')->has_value($self);
            
            return {
                min => $species_stats->{min_orbit},
                max => $species_stats->{max_orbit},
            }
        };
    }
    
    if ('space_station' ~~ $p->attributes) {
        has 'space_station' => (
            isa         => 'Str',
            is          => 'ro',
            documentation=> q[Space station to be managed],
            required    => 1,
        );
        
        has 'space_station_data' => (
            isa             => 'HashRef',
            is              => 'rw',
            traits          => ['NoGetopt'],
            lazy_build      => 1,
        );
        
        method '_build_space_station_data' => sub {
            my ($self) = @_;
            my $space_station = $self->my_body_status($self->space_station);
            unless (defined $space_station
                && $space_station->{type} eq 'space station') {
                $self->abort('Could not find space station "%s"',$self->space_station);
            }
            
            return $space_station;
        };
    }

    if ('dispose_percentage' ~~ $p->attributes) {
        has 'dispose_percentage' => (
            isa     => 'Int',
            is      => 'rw',
            required=>1,
            default => 80,
            documentation => 'Dispose waste if waste storage is n-% full',
        );
    }

    if ('start_building_at' ~~ $p->attributes) {
        has 'start_building_at' => (
            isa     => 'Int',
            is      => 'rw',
            required=> 1,
            default => 0,
            documentation => 'Upgrade buildings if there are less than N buildings in the build queue',
        );
    }
    
    if ('plan_for_hours' ~~ $p->attributes) {
        has 'plan_for_hours' => (
            isa     => 'Num',
            is      => 'rw',
            required=> 1,
            default => 1,
            documentation => 'Plan N hours ahead',
        );
    }
    
    if ('keep_waste_hours' ~~ $p->attributes) {
        has 'keep_waste_hours' => (
            isa     => 'Num',
            is      => 'rw',
            required=> 1,
            default => 24,
            documentation => 'Keep enough waste for N hours',
        );
    }
    
    if ('target_planet' ~~ $p->attributes) {
        has 'target_planet' => (
            is      => 'rw',
            isa     => 'Str',
            required=> 1,
            documentation => 'Target planet (Name, ID or Coordinates)  [Required]',
        );
        
        has 'target_planet_data' => (
            isa             => 'HashRef',
            is              => 'rw',
            traits          => ['NoGetopt'],
            lazy_build      => 1,
        );
        
        method 'target_planet_hash' => sub {
            my ($self) = @_;
            
            given ($self->target_planet) {
                when (/^\d+$/) {
                    return { 'body_id' => $_ };
                }
                when (/^(?<x>-?\d+),(?<y>-?\d+)$/) {
                    return { 'x' => $+{x}, 'y' => $+{y} };
                }
                default {
                    return { 'body_name' => $_ };
                }
            }
        };
        
        method '_build_target_planet_data' => sub {
            my ($self) = @_;
            my $target_planet;
            given ($self->target_planet) {
                when (/^\d+$/) {
                    $target_planet = $self->get_body_by_id($_);
                }
                when (/^(?<x>-?\d+),(?<y>-?\d+)$/) {
                    $target_planet = $self->get_body_by_xy($+{x},$+{y});
                }
                default {
                    $target_planet = $self->get_body_by_name($_);
                }
            }
            unless (defined $target_planet) {
                $self->abort('Could not find target planet "%s"',$self->target_planet);
            }
            return $target_planet;
        };
    }
    
    if ('mytarget_planet' ~~ $p->attributes) {
        has 'target_planet' => (
            is      => 'rw',
            isa     => 'Str',
            required=> 1,
            documentation => 'Target planet [Required]',
        );
        
        has 'target_planet_data' => (
            isa             => 'HashRef',
            is              => 'rw',
            traits          => ['NoGetopt'],
            lazy_build      => 1,
        );
        method '_build_target_planet_data' => sub {
            my ($self) = @_;
            my $target_planet = $self->my_body_status($self->target_planet);
            unless (defined $target_planet) {
                $self->abort('Could not find target planet "%s"',$self->target_planet);
            }
            return $target_planet;
        };
    }
    
    if ('home_planet' ~~ $p->attributes) {
        has 'home_planet' => (
            is      => 'rw',
            isa     => 'Str',
            required=> 1,
            documentation => 'Home planet  [Required]',
        );
        
        has 'home_planet_data' => (
            isa             => 'HashRef',
            is              => 'rw',
            traits          => ['NoGetopt'],
            lazy_build      => 1,
        );
        method '_build_home_planet_data' => sub {
            my ($self) = @_;
            my $home_planet = $self->my_body_status($self->home_planet);
            unless (defined $home_planet) {
                $self->abort('Could not find home planet "%s"',$self->home_planet);
            }
            return $home_planet;
        };
    }
};

1;

=encoding utf8

=head1 NAME

Games::Lacuna::Role::CommonAttributes - Attributes utilized by multiple actions

=head1 SYNOPSIS

 package Games::Lacuna::Task::Action::MyTask;
 use Moose;
 extends qw(Games::Lacuna::Task::Action);
 with 'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['dispose_percentage'] };

=head1 DESCRIPTION

The following accessors and helper methods are available on request

=head2 home_planet

Own planet. Planet stats can be accessed via the C<home_planet_data> method.

=head2 target_planet

Foreign planet. Planet stats can be accessed via the C<target_planet_data> 
method.

=head2 mytarget_planet

Own target planet. Planet stats can be accessed via the C<target_planet_data> 
method.

=head2 dispose_percentage

Dispose waste if waste storage is n-% full

=head2 start_building_at

Upgrade buildings if there are less than N buildings in the build queue

=head2 plan_for_hours

Plan N hours ahead

=head2 keep_waste_hours

Keep enough waste for N hours',

=head2 space_station

Own space station. Station stats can be accessed via the C<space_station_data> method.

=cut