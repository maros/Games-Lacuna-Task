package Games::Lacuna::Task::Action::Recycle;

use 5.010;

use Moose;
use List::Util qw(min);

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

sub run {
    my ($self) = @_;
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        
        my %ressources;
        my $total_ressources = 0;
        my $total_ressources_coeficient = 0;
        my $total_waste_coeficient = 0;
        
        # Get stored waste
        my $waste = $planet_stats->{waste_stored};
        
        # Get stored ressources
        foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
            my $stored = $planet_stats->{$ressource.'_stored'}+0;
            my $capacity = $planet_stats->{$ressource.'_capacity'}+0;
            $ressources{$ressource} = [ $capacity-$stored, 0, 0];
            $total_ressources += $capacity-$stored;
        }
        
        # Fallback if storage is full
        if ($total_ressources == 0) {
            foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
                my $capacity = $planet_stats->{$ressource.'_capacity'}+0;
                $ressources{$ressource}[0] = $capacity;
                $total_ressources += $capacity;
            }
        }
        
        # Calculate ressouces
        foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
            $ressources{$ressource}[1] =  ($ressources{$ressource}[0] / $total_ressources);
            if ($ressources{$ressource}[1] > 0
                && $ressources{$ressource}[1] < 1) {
                $ressources{$ressource}[1] = 1-($ressources{$ressource}[1]);
            }
            $total_ressources_coeficient += $ressources{$ressource}[1];
        }
        
        # Calculate recycling relations
        foreach my $ressource (@Games::Lacuna::Task::Constants::RESSOURCES) {
            $ressources{$ressource}[2] = ($ressources{$ressource}[1] / $total_ressources_coeficient);
        }
        
        my $recycling_buildings = $self->building_type($planet_stats->{id},'Waste Recycling Center');
        
        foreach my $building_id (keys %{$recycling_buildings}) {
            my $building_data = $recycling_buildings->{$building_id};
            
            next
                if defined $building_data->{work};
            
            my $recycling_object = Games::Lacuna::Client::Buildings::WasteRecycling->new(
                client      => $self->client->client,
                id          => $building_id,
            );
            
            my $recycling_data = $self->request(
                object  => $recycling_object,
                method  => 'view',
            );
            
            my $recycle_quantity = min($waste,$recycling_data->{recycle}{max_recycle});
            
            my %recycle = (map { $_ => int($ressources{$_}[2] * $recycle_quantity) } keys %ressources);
            
            $self->log('notice',"Recycling %i %s, %i %s, %i %s on %s",(map { ($recycle{$_},$_) } @Games::Lacuna::Task::Constants::RESSOURCES),$planet_stats->{name});
            
            $self->request(
                object  => $recycling_object,
                method  => 'recycle',
                params  => [ (map { $recycle{$_} } @Games::Lacuna::Task::Constants::RESSOURCES) ],
            );
            
            $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;