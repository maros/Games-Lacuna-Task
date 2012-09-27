package Games::Lacuna::Task::Action::StationUpgrade;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['space_station'] };
use Games::Lacuna::Task::Utils qw(parse_date);

sub description {
    return q[Upgrade Space Station modules];
}

sub run {
    my ($self) = @_;
    
    my $space_station = $self->space_station_data();
    my $timestamp = time();
    
    my $station_command = $self->find_building($space_station->{id},'StationCommand');
    my $station_command_level = $station_command->{level};
    
    MODULE:
    foreach my $module_data ($self->buildings_body($space_station)) {
        
        next MODULE
            if $module_data->{name} eq 'Supply Pod';
        
        next MODULE
            if $module_data->{level} >= $station_command_level 
            && $module_data->{name} ne 'Station Command Center';
        
        if (defined $module_data->{pending_build}) {
            my $date_end = parse_date($module_data->{pending_build}{end});
            next MODULE
                if $timestamp < $date_end;
        }
        
        my $module_object = $self->build_object($module_data);
        
        # Check upgrade
        my $module_data = $self->request(
            object  => $module_object,
            method  => 'view',
        );
        
        next MODULE
            unless $module_data->{building}{upgrade}{can};
        
        $self->log('notice',"Upgrading %s on %s",$module_data->{'name'},$space_station->{name});
        
        # Upgrade request
        $self->request(
            object  => $module_object,
            method  => 'upgrade',
        );
    }
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

=pod

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::StationUpgrade - Upgrade Space Station modules

=head1 DESCRIPTION

This task upgrades space station modules if plans are avaialable

=cut