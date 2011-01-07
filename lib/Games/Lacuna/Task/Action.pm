package Games::Lacuna::Task::Action;

use 5.010;

use Moose;

sub run {
    my ($self) = @_;
    
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        $self->process_planet($planet_stats);
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;