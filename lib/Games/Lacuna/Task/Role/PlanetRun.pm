package Games::Lacuna::Task::Role::PlanetRun;

use 5.010;
use Moose::Role;

sub run {
    my ($self) = @_;
    
    PLANETS:
    foreach my $planet_stats ($self->my_planets) {
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