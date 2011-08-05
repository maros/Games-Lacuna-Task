package Games::Lacuna::Task::Action::FetchSpy;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Stars',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['target_planet','home_planet'] };

sub description {
    return q[Fetch spies from other planets];
}

sub run {
    my ($self) = @_;
    my $planet_home = $self->home_planet_data();
    my $planet_target = $self->target_planet_data();
    
    # Get intelligence ministry
    my ($spaceport) = $self->find_building($planet_home->{id},'Spaceport');
    return $self->log('error','Could not find spaceport')
        unless (defined $spaceport);
    my $spaceport_object = $self->build_object($spaceport);

    my $fetchable_spies = $self->request(
        object      => $spaceport_object,
        method      => 'prepare_fetch_spies',
        params      => [$planet_target->{id},$planet_home->{id}],
    );
    
    unless (scalar @{$fetchable_spies->{spies}}) {
        $self->log('err','No spies available to fetch');
        return;
    }
    
    die $fetchable_spies->{spies};
    die $fetchable_spies->{ships};
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;