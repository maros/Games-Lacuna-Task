package Games::Lacuna::Task::Automator;

use 5.010;

use Moose;
with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

sub run {
    my ($self) = @_;
    
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        next
            unless $planet_stats->{type} eq 'habitable planet';
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        $self->process_planet($planet_stats);
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
