package Games::Lacuna::Task::Role::PlanetRun;

use 5.010;
use Moose::Role;

has 'exclude_planet' => (
    is              => 'rw',
    isa             => 'ArrayRef[Str]',
    documentation   => 'Do not process given planets',
    traits          => ['Array'],
    default         => sub { [] },
    handles         => {
        'has_exclude_planet' => 'count',
    }
);

sub run {
    my ($self) = @_;
    
    my @exclude_planets;
    if ($self->has_exclude_planet) {
        foreach my $planet (@{$self->exclude_planet}) {
            my $planet_id = $self->my_body_id($planet);
            push(@exclude_planets,$planet_id)
                if $planet_id;
        }
    }
    
    PLANETS:
    foreach my $planet_stats ($self->my_planets) {
        next PLANETS
            if $planet_stats->{id} ~~ \@exclude_planets;
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        $self->process_planet($planet_stats);
    }
}

no Moose::Role;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Role::PlanetRun - Helper role for all planet-centric actions

=cut