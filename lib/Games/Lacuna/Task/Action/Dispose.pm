package Games::Lacuna::Task::Action::Dispose;

use 5.010;

use Moose;

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

has 'dispose_percentage' => (
    isa     => 'Int',
    is      => 'rw',
    required=>1,
    default => 90,
    documentation => 'Dispose waste if waste storage is n-% full',
);

sub run {
    my ($self) = @_;
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        
        # Get stored waste
        my $waste = $planet_stats->{waste_stored};
        my $waste_capacity = $planet_stats->{waste_capacity};
        my $waste_filled = ($waste / $waste_capacity) * 100;
        
        # Check if waste is overflowing
        next 
            if ($waste_filled < $self->dispose_percentage);
        
        # Get space port
        my ($spaceport) = $self->find_building($planet_stats->{id},'Space Port');
        
        next
            unless $spaceport;
            
        my $spaceport_object = Games::Lacuna::Client::Buildings::SpacePort->new(
            client      => $self->client->client,
            id          => $spaceport->{id},
        );
        
        my $spaceport_data = $self->paged_request(
            object  => $spaceport_object,
            method  => 'view_all_ships',
            total   => 'number_of_ships',
            data    => 'ships',
        );
        
        foreach my $ship (@{$spaceport_data->{ships}}) {
            next
                unless $ship->{task} eq 'Docked';
            next
                unless $ship->{type} eq 'scow';
            next
                if $ship->{hold_size} > $waste;
            
            $self->log('notice',"Disposing %s waste on %s",$ship->{hold_size},$planet_stats->{name});
            
            # Send scow to closest star
            my $spaceport_data = $self->request(
                object  => $spaceport_object,
                method  => 'send_ship',
                params  => [ $ship->{id},{ "star_id" => $planet_stats->{star_id} } ],
            );
            
            $self->clear_cache('body/'.$planet_stats->{id});
            
            next PLANETS;
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;