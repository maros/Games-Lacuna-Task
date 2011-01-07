package Games::Lacuna::Task::Action::Bleeder;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my (@bleeders) = $self->find_building($planet_stats->{id},'Deployed Bleeder');
    
    if (scalar @bleeders) {
        $self->log('warn','There are %i bleeders on %s',scalar(@bleeders),$planet_stats->{name});
        
        foreach my $bleeder (@bleeders) {
            
            my $bleeder_object = $self->build_object($bleeder);
            
            # Demolish bleeder
            $self->request(
                object  => $bleeder_object,
                method  => 'demolish',
            );
            
            $self->clear_cache('body/'.$planet_stats->{id});
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;