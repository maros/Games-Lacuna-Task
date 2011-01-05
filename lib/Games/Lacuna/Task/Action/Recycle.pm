package Games::Lacuna::Task::Action::Recycle;

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
        my %ressources;
        my $total_ressources = 0;
        
        # Get stored waste
        my $waste = $planet_stats->{waste_stored};
        
        # Get stored ressources
        foreach my $ressource (@Lacuna::Task::Constants::RESSOURCES) {
            my $method = $ressource.'_stored';
            $ressources{$ressource} = [ $planet_stats->{$method}, 0, 0 ];
            $total_ressources += $ressources{$ressource}[0];
        }
        
        # Calculate ressouces
        my $total_ressources_coeficient = 0;
        foreach my $ressource (@Lacuna::Task::Constants::RESSOURCES) {
            $ressources{$ressource}[1] =  1 - ($ressources{$ressource}[0] / $total_ressources);
            $total_ressources_coeficient += $ressources{$ressource}[1];
        }
        foreach my $ressource (@Lacuna::Task::Constants::RESSOURCES) {
            $ressources{$ressource}[2] = int($waste * ($ressources{$ressource}[1] / $total_ressources_coeficient));
        }
        
        my $recycling_buildings = $self->building_type($planet_stats->{id},'Waste Recycling Center');
        
        foreach my $building_id (keys %{$recycling_buildings}) {
            my $building_data = $recycling_buildings->{$building_id};
            
            next
                if defined $building_data->{work};
            
            my $recycling_building = Games::Lacuna::Client::Buildings::WasteRecycling->new(
                client      => $self->client->client,
                id          => $building_id,
            );
            
            my $recycling_detail = $recycling_building->view();
            
            die Data::Dumper::Dumper $recycling_detail;
            
            $self->log('debug',"Recycling for %s",$planet_stats->{name});
            
            my %recycle = (map { $_ => $ressources{$_}[2] } keys %ressources);
            $recycling_building->recycle(\%recycle);
        }
        
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;