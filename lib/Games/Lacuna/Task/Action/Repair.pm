package Games::Lacuna::Task::Action::Repair;

use 5.010;

use Moose;

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

sub run {
    my ($self) = @_;
    
    # Loop all planets
    foreach my $planet_stats ($self->planets) {
        $self->log('debug',"Planet %s",$planet_stats->{name});
        
        my $buildings = $self->buildings_body($planet_stats->{id});
        
        # Loop all buildings
        foreach my $building (keys %{$buildings}) {
            my $building_data = $buildings->{$building};
            
            # Check if building needs to be repaired
            next
                if $building_data->{efficiency} == 100;
            
            # Repair building
            $self->log('debug',"Repairing %s",$building_data->{name});
            
            my $building_object = Games::Lacuna::Client::Buildings->new(
                client      => $self->client->client,
                id          => $building->{id},
            );
            
            $building_object->repair();
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;