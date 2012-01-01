package Games::Lacuna::Task::Action::Cleanup;

use 5.010;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);

sub description {
    return q[Various cleanup tasks];
}

sub run {
    my ($self) = @_;
    
    $self->cleanup_database();
}

sub cleanup_database {
    my ($self) = @_;
    
    $self->log('info','Cleanup database');
    
    my $storage = $self->client->storage;
    
    $storage->scan(sub {
        my ($object) = @_;
        
        return
            unless blessed $object && $object->isa('Games::Lacuna::Task::Cache');
        
        unless ($object->is_valid) {
            $self->log('debug','Deleting cache object %s',$object->key);
            $storage->delete($object->key);
        }
    })
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;