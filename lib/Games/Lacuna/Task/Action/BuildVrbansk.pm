package Games::Lacuna::Task::Action::BuildVrbansk;

use 5.010;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Building',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['home_planet'] };

use List::Util qw(min);

has 'count' => (
    isa         => 'Int',
    is          => 'ro',
    required    => 1,
    default     => 1,
    documentation=> q[Number of halls to be build],
);

sub description {
    return q[Build halls of vrbansk on a given planet];
}

sub run {
    my ($self) = @_;
    
    my $planet_home = $self->home_planet_data();
    
    # Get pcc
    my $planetarycommand = $self->find_building($planet_home->{id},'PlanetaryCommand');
    return 
        unless $planetarycommand;
    
    my $planetarycommand_object = $self->build_object($planetarycommand);
    
    # Get plans
    my $plan_data = $self->request(
        object  => $planetarycommand_object,
        method  => 'view_plans',
    );
    
    my $vrbansk = 0;
    foreach my $plan (@{$plan_data->{plans}}) {
        next
            unless $plan->{name} eq 'Halls of Vrbansk';
        next
            if $plan->{extra_build_level} != 0;
        $vrbansk++;
    }
    
    return $self->log('error','Could not find plans for Hall of Vrbansk')
        if $vrbansk == 0;
    

    my $buildable_spots = $self->find_buildspot($planet_home);
    
    return $self->log('error','Could not find build spots')
        if scalar @{$buildable_spots} == 0;
    
    HALL:
    for (1..min($self->count,$vrbansk)) {
        my $buildable_spot = pop(@{$buildable_spots});
        
        my $new_vrbansk_object = $self->build_object('/hallsofvrbansk', body_id => $planet_home->{id});
        
        $self->log('notice',"Building Hall of Vrbansk on %s",$planet_home->{name});
        
        $self->request(
            object  => $new_vrbansk_object,
            method  => 'build',
            params  => [ $planet_home->{id}, $buildable_spot->[0],$buildable_spot->[1]],
        );
    }
    
    $self->clear_cache('body/'.$planet_home->{id}.'/buildings');
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;