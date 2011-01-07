package Games::Lacuna::Task::Action::Repair;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

sub description {
    return q[This task automates the repair of damaged buildings];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my @buildings = $self->buildings_body($planet_stats->{id});
    
    # Loop all buildings
    foreach my $building_data (@buildings) {
        # Check if building needs to be repaired
        next
            if $building_data->{efficiency} == 100;
        
        my $building_object = $self->build_object($building_data);
        my $building_detail = $self->request(
            object  => $building_object,
            method  => 'view',
        );
        
        # Check if we can afford repair
        next
            unless $self->can_afford($planet_stats,$building_detail->{building}{repair_costs});
        
        # Repair building
        $self->log('notice',"Repairing %s on %s",$building_data->{name},$planet_stats->{name});
        
        $self->request(
            object  => $building_object,
            method  => 'repair',
        );
        
        $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;