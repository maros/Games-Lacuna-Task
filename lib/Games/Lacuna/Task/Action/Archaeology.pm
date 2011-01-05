package Games::Lacuna::Task::Action::Archaeology;

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
        
        my $archaeology_ministry = $self->building_type_single($planet_stats->{id},'Archaeology Ministry');
        
        next
            unless defined $archaeology_ministry;
        next
            if defined $archaeology_ministry->{work};
        
        # Get local ores
        my %ores;
        foreach my $ore (keys %{$planet_stats->{ore}}) {
            $ores{$ore} = 1
                if $planet_stats->{ore}{$ore} > 1;
        }
        
        # Get local ores form mining platforms
        my $mining_ministry = $self->building_type_single($planet_stats->{id},'Mining Ministry');
        if (defined $mining_ministry) {
            my $mining_ministry_building = Games::Lacuna::Client::Buildings::MiningMinistry->new(
                client      => $self->client->client,
                id          => $mining_ministry->{id},
            );
            my $platforms = $mining_ministry_building->view_platforms;
            
            if (defined $platforms
                && $platforms->{platforms}) {
                foreach my $platform (@{$platforms->{platforms}}) {
                    foreach my $ore (keys %{$platform->{asteroid}{ore}}) {
                        $ores{$ore} = 1
                            if $platform->{asteroid}{ore}{$ore} > 1;
                    }
                }
            }
        }
        
        # Get stored ores
        my $ore_storage_tanks = $self->building_type_single($planet_stats->{id},'Ore Storage Tanks');
        
        next
            unless $ore_storage_tanks;
        
        my $ore_storage_building = Games::Lacuna::Client::Buildings::OreStorage->new(
            client      => $self->client->client,
            id          => $ore_storage_tanks->{id},
        );
        
        my $ore_storage_data = $ore_storage_building->view();
        if ($ore_storage_data) {
            foreach my $ore (keys %{$ore_storage_data->{ore_stored}}) {
                next
                    unless defined $ores{$ore};
                $ores{$ore} = $ore_storage_data->{ore_stored}{$ore};
                delete $ores{$ore}
                    if $ores{$ore} < 10000;
            }
        }
           
        warn Data::Dumper::Dumper \%ores;
        
        my $archaeology_ministry_building = Games::Lacuna::Client::Buildings::Archaeology->new(
            client      => $self->client->client,
            id          => $archaeology_ministry->{id},
        );
        
        #warn Data::Dumper::Dumper $archaeology_ministry_building->view()



#        foreach my $building_id (keys %{$recycling_buildings}) {
#            my $building_data = $recycling_buildings->{$building_id};
#            
#            next
#                if defined $building_data->{work};
#            
#            my $recycling_building = Games::Lacuna::Client::Buildings::WasteRecycling->new(
#                client      => $self->client->client,
#                id          => $building_id,
#            );
#            
#            my $recycling_detail = $recycling_building->view();
#            
#            die Data::Dumper::Dumper $recycling_detail;
#            
#            $self->log('debug',"Recycling for %s",$planet_stats->{name});
#            
#            my %recycle = (map { $_ => $ressources{$_}[2] } keys %ressources);
#            $recycling_building->recycle(\%recycle);
#        }
        
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;