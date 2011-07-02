package Games::Lacuna::Task::Role::Building;

use 5.010;
use Moose::Role;

sub upgrade_building {
    my ($self,$planet_stats,$building_data) = @_;
    
    my $building_object = $self->build_object($building_data);
    my $building_detail = $self->request(
        object  => $building_object,
        method  => 'view',
    );
    
    return 0
        unless $building_detail->{building}{upgrade}{can};
    
    # Check if we really can afford the upgrade
    return 0
        unless $self->can_afford($planet_stats,$building_detail->{'building'}{upgrade}{cost});
    
    # Check if upgraded building is sustainable
    {
        no warnings 'once';
        foreach my $resource (@Games::Lacuna::Task::Constants::RESOURCES_ALL) {
            my $resource_difference = -1 * ($building_detail->{'building'}{$resource.'_hour'} - $building_detail->{'building'}{upgrade}{production}{$resource.'_hour'});
            return 0
                if ($planet_stats->{$resource.'_hour'} + $resource_difference <= 0);
        }
    }
    
    $self->log('notice',"Upgrading %s on %s",$building_detail->{'building'}{'name'},$planet_stats->{name});
    
    # Upgrade request
    $self->request(
        object  => $building_object,
        method  => 'upgrade',
    );
    
    $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
    
    return 1;
}

sub find_buildspot {
    my ($self,$body) = @_;
    
    my $body_id = $self->find_body($body);
    
    return []
        unless $body_id;
    
    my @occupied;
    foreach my $building_data ($self->buildings_body($body_id)) {
        push (@occupied,$building_data->{x}.';'.$building_data->{y});
    }
    
    my @buildable;
    for my $x (-5..5) {
        for my $y (-5..5) {
            next
                if $x.';'.$y ~~ @occupied;
            push(@buildable,[$x,$y]);
        }
    }
    
    return \@buildable;
}

1;