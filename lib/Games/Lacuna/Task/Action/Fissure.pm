package Games::Lacuna::Task::Action::Fissure;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun);

use List::Util qw(max sum);

sub description {
    return q[Downgrade fissures];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get archaeology ministry
    my @fissures = $self->find_building($planet_stats->{id},'Fissure');
    
    return
        unless defined scalar @fissures;
    
    foreach my $fissure (@fissures) {
        $self->log(
            'warn',
            'Found level %i fissure at %s',
            $fissure->{level},
            $planet_stats->{name}
        );
        
        my $fissure_object = $self->build_object($fissure);
        
        my $fissure_data = $self->request(
            object  => $fissure_object,
            method  => 'view',
        );
        
        my $building_data = $fissure_data->{building};
        
        if ($building_data->{level} == 1) {
            $self->log('notice','Demolish fissure on %s',$planet_stats->{name});
            
            $self->request(
                object  => $fissure_object,
                method  => 'downgrade',
            );
        } elsif ($building_data->{downgrade}{can}) {
            $self->log('notice','Downgrade fissure on %s',$planet_stats->{name});
            
            $self->request(
                object  => $fissure_object,
                method  => 'demolish',
            );
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::Fissure - Downgrade fissures

=head1 DESCRIPTION

This task will automate the downgrade and demoloition of fissures.

=cut

