package Games::Lacuna::Task::Action::Dispose;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);

has 'dispose_percentage' => (
    isa     => 'Int',
    is      => 'rw',
    required=>1,
    default => 80,
    documentation => 'Dispose waste if waste storage is n-% full',
);

sub description {
    return q[This task automates the disposal of overflowing waste];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get stored waste
    my $waste = $planet_stats->{waste_stored};
    my $waste_capacity = $planet_stats->{waste_capacity};
    my $waste_filled = ($waste / $waste_capacity) * 100;
    
    # Check if waste is overflowing
    return 
        if ($waste_filled < $self->dispose_percentage);
    
    # Get space port
    my ($spaceport) = $self->find_building($planet_stats->{id},'SpacePort');
    
    return
        unless $spaceport;
        
    my $spaceport_object = $self->build_object($spaceport);
    my $spaceport_data = $self->paged_request(
        object  => $spaceport_object,
        method  => 'view_all_ships',
        total   => 'number_of_ships',
        data    => 'ships',
    );
    
    # Get all available scows
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
        
        $waste -= $ship->{hold_size};
        $waste_filled = ($waste / $waste_capacity) * 100;
        
        # Check if waste is overflowing
        return 
            if ($waste_filled < $self->dispose_percentage);
        
        $self->clear_cache('body/'.$planet_stats->{id});
    }
    
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;