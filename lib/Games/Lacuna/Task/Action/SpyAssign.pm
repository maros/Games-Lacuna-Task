package Games::Lacuna::Task::Action::SpyAssign;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun
    Games::Lacuna::Task::Role::Intelligence);

sub description {
    return q[Assigns spies (requires captcha)];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my @bodies = $self->my_bodies;
    
    # Get intelligence ministry
    my ($intelligence_ministry) = $self->find_building($planet_stats->{id},'Intelligence');
    return
        unless $intelligence_ministry;
    my $intelligence_ministry_object = $self->build_object($intelligence_ministry);
    
    my $spy_data = $self->paged_request(
        object  => $intelligence_ministry_object,
        method  => 'view_spies',
        total   => 'spy_count',
        data    => 'spies',
    );
    
    foreach my $spy (@{$spy_data->{spies}}) {
        if ($spy->{assigned_to}{body_id} ~~ \@bodies) {
            $self->assign_spy($intelligence_ministry_object,$spy,"Counter Espionage")
        }
    }
    
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::SpyFetch - Fetch spies from enemy planets

=head1 DESCRIPTION

This task manual task fetches a given number of spies from a selected planet

=cut