package Games::Lacuna::Task::Role::Client;

use 5.010;
use Moose::Role;

use Games::Lacuna::Task::Client;

my %CLIENTS;
our $DEFAULT_DATABASE= Path::Class::File->new($ENV{HOME}.'/.lacuna/default.db');

has 'database' => (
    is              => 'ro',
    isa             => 'Path::Class::File',
    coerce          => 1,
    documentation   => 'Path to the lacuna database file',
    default         => sub { return $DEFAULT_DATABASE },
    traits          => ['KiokuDB::DoNotSerialize'],
);

has 'client' => (
    is              => 'ro',
    isa             => 'Games::Lacuna::Task::Client',
    traits          => ['NoGetopt','KiokuDB::DoNotSerialize'],
    lazy_build      => 1,
);

sub _build_client {
    my ($self) = @_;
    
    my $database_stringify = $self->database->stringify;
    
    # See if we have client in cache
    if (defined $CLIENTS{$database_stringify}) {
        return $CLIENTS{$database_stringify};
    }
    
    # Build new client
    my $client = Games::Lacuna::Task::Client->new(
        loglevel        => $self->loglevel,
        storage_file    => $self->database,
        debug           => 1,
    );
    
    $CLIENTS{$database_stringify} = $client;
    
    return $client;
}

sub request {
    my ($self,%params) = @_;
    
    my $method = delete $params{method};
    my $type = delete $params{type};
    my $object = delete $params{object};
    my $params = delete $params{params} || [];
    
    unless (defined $object) {
        $object = $self
            ->client
            ->client
            ->$type(%params,verbose_rpc => 1);
    
        $self->log('debug',"Run external request %s/%s",$type,$method);
    } else {
        $self->log('debug',"Run external request %s/%s",ref($object),$method);
    }
    my $request = $object->$method(@$params);
    
    my $status = $request->{status} || $request;
    if ($status->{empire}) {
        $self->write_cache(
            key     => 'empire',
            value   => $status->{empire},
            max_age => 21600,
        );
    }
    if ($status->{body}) {
        $self->write_cache(
            key     => 'body/'.$status->{body}{id},
            value   => $status->{body},
        );
    }
    if ($request->{buildings}) {
        $self->write_cache(
            key     => 'body/'.$status->{body}{id}.'/buildings',
            value   => $request->{buildings},
            max_age => 600,
        );
    }
    
    return $request;
}


sub lookup_cache {
    my ($self,$key) = @_;
    
    my $storage = $self->client->storage;
    my $cache = $storage->lookup($key);
    return
        unless defined $cache;
    if (blessed $cache
        && $cache->isa('Games::Lacuna::Task::Cache')) {
        return
            unless $cache->is_valid;
        return $cache->value
    } else {
        return $cache;
    }
}

sub write_cache {
    my ($self,%params) = @_;
    
    my $storage = $self->client->storage;
    $params{max_age} += time()
        if $params{max_age};
   
    my $cache = Games::Lacuna::Task::Cache->new(
        %params
    );
    
    $cache->store($storage);
    
    return $cache;
}

sub clear_cache {
    my ($self,$key) = @_;
    
    my $storage = $self->client->storage;
    $storage->delete($key);
}


no Moose::Role;
1;