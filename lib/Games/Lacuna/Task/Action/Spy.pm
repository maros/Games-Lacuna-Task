package Games::Lacuna::Task::Action::Spy;

use 5.010;

use List::Util qw(min shuffle);

use Moose;
extends qw(Games::Lacuna::Task::Action);

has 'rename_spies' => (
    isa             => 'Bool',
    is              => 'rw',
    default         => 1,
    documentation   => 'Rename spies if they carry the default name',
);

has 'max_training' => (
    isa             => 'Int',
    is              => 'rw',
    default         => 2,
    documentation   => 'Max number of spies in training',
);

our @TRAINING_BUILDINGS = qw(IntelTraining TheftTraining PoliticsTraining MayhemTraining);

sub description {
    return q[This task automates the training of spies];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Get intelligence ministry
    my ($intelligence_ministry) = $self->find_building($planet_stats->{id},'Intelligence');
    return
        unless $intelligence_ministry;
    my $intelligence_ministry_object = $self->build_object($intelligence_ministry);
    
    my $ministry_data = $self->request(
        object  => $intelligence_ministry_object,
        method  => 'view',
    );
    
    my $spies_in_training = $ministry_data->{spies}{in_training};
    
    # Check if we can have more spies
    my $spy_slots = $ministry_data->{spies}{maximum} > $ministry_data->{spies}{current};
    
    if ($spy_slots > 0
        && $self->can_afford($planet_stats,$ministry_data->{spies}{training_costs})) {
        $self->log('notice',"Training spy on %s",$planet_stats->{name});
        $self->request(
            object  => $intelligence_ministry_object,
            method  => 'train_spy',
            params  => [1]
        );
    }
    
    return 
        if $spies_in_training >= $self->max_training;
    
    TRAINING_BUILDING:
    foreach my $building_name (shuffle @TRAINING_BUILDINGS) {
        my ($training_building) = $self->find_building($planet_stats->{id},$building_name);
        next
            unless $training_building;
        my $training_building_object = $self->build_object($training_building);
        my $training_building_data = $self->request(
            object  => $training_building_object,
            method  => 'view',
        );
        
        next TRAINING_BUILDING
            if scalar @{$training_building_data->{spies}{training_costs}{time}} == 0;
        
        my $spy = $training_building_data->{spies}{training_costs}{time}[0];
        
        $self->log('notice',"Training spy on %s at %s",$planet_stats->{name},$building_name);

        $self->request(
            object  => $training_building_object,
            method  => 'train_spy',
            params  => [$spy->{spy_id}],
        );
        
        $spies_in_training ++;
        
        return 
            if $spies_in_training >= $self->max_training;
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
