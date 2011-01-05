package Games::Lacuna::Task::Action::Repair;

use 5.010;

use Moose;

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

sub run {
    my ($self) = @_;
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        
        my $buildings = $self->buildings_body($planet_stats->{id});
        
        # Loop all buildings
        foreach my $building (keys %{$buildings}) {
            my $building_data = $buildings->{$building};
            
            # Check if building needs to be repaired
            next
                if $building_data->{efficiency} == 100;
            
            # Repair building
            $self->log('notice',"Repairing %s on %s",$building_data->{name},$planet_stats->{name});
            
            my $building_class = $self->building_class($building_data->{url});
            
            my $building_object = $building_class->new(
                client      => $self->client->client,
                id          => $building->{id},
            );
            
            $self->request(
                object  => $building_object,
                method  => 'repair',
            );
            
            $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;