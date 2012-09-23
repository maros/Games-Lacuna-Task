package Games::Lacuna::Task::Action::VrbanskUpgrade;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Building',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['home_planet'] };

use List::Util qw(min);

has 'level' => (
    isa         => 'Int',
    is          => 'ro',
    required    => 1,
    documentation=> "Upgrade building to the given level",
);

has 'building' => (
    isa         => 'Str',
    is          => 'ro',
    required    => 1,
    documentation=> "Which buildimg to upgrdade",
);


sub description {
    return q[Upgrade a building with halls of vrbansk];
}

sub run {
    my ($self) = @_;
    
    my $planet_home = $self->home_planet_data();
    my $global_found = 0;
    
    HALLS:
    while (1) {
        # Get pcc 
        my $hall = $self->get_hall();
        
        last HALLS 
            unless defined $hall;
        my $hall_object = $self->build_object($hall);
        
        # Get buildings
        my $upgrade_data = $self->request(
            object  => $hall_object,
            method  => 'get_upgradable_buildings',
        );
        
        my $found = 0;
        foreach my $building (@{$upgrade_data->{buildings}}) {
            next 
                if ($building->{level} >= $self->level);
            next 
                if (lc($building->{name}) ne lc($self->building));
            
            $self->log('notice',"Upgrading %s to level %i on %s",$building->{'name'},$building->{'level'}+1,$planet_home->{name});
            $global_found = $found = 1;
            
            # Get buildings
            my $response = $self->request(
                object  => $hall_object,
                method  => 'sacrifice_to_upgrade',
                params  => [$building->{id}],
            );
            
            $self->clear_cache('body/'.$planet_home->{id}.'/buildings');
            sleep 15 + 15;
            next HALLS;
        }
        
        last HALLS
            if $found == 0;
    }
    
    $self->abort('Could not find %s to upgrade',$self->building)
        unless $global_found;
}

sub get_hall {
    my ($self) = @_;
    
    my $planet_home = $self->home_planet_data();
    
    # Get halls of vrbansk
    my $hall = $self->find_building($planet_home->{id},'HallsOfVrbansk');
    
    return $hall
        if defined $hall;
    
    my $builspots = $self->find_buildspot($planet_home);
    
    return $self->log('error','Could not find build spots')
        if scalar @{$builspots} == 0;
        
    my $new_vrbansk_object = $self->build_object('/hallsofvrbansk', body_id => $planet_home->{id});
    $self->log('notice',"Building Hall of Vrbansk on %s",$planet_home->{name});

    foreach my $builspot (@{$builspots}) {
        my $response = $self->request(
            object  => $new_vrbansk_object,
            method  => 'build',
            params  => [ $planet_home->{id}, $builspot->[0],$builspot->[1]],
            catch   => [
               [
                    1009,
                    qr/That space is already occupied/,
                    sub {
                        $self->log('debug',"Could not build Hall of Vrbansk on %s: Build spot occupied",$planet_home->{name});
                        return 0;
                    }
                ],
                [
                    1009,
                    qr/There's no room left in the build queue/,
                    sub {
                        $self->log('debug',"Could not build Hall of Vrbansk on %s: Build queue full",$planet_home->{name});
                        return 0;
                    }
                ],
            ],
        );
        
        next
            unless defined $response;
        
        $self->clear_cache('body/'.$planet_home->{id}.'/buildings');
        sleep $response->{building}{pending_build}{seconds_remaining} + 1;
        
        my $return = $response->{building};
        $return->{x} = $builspot->[0];
        $return->{y} = $builspot->[1];
        $return->{level} = 1;
        $return->{url} = '/hallsofvrbansk';
        return $return; 
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::VrbanskBuild - Build Halls of Vrbansk plans 

=head1 DESCRIPTION

This task will build the selected quantity of Halls of Vrbansk plans.

Note that this method is somewhat deprecated since it enough to build a 
single Hall of Vrbansk to upgrade a glyph building.

=cut