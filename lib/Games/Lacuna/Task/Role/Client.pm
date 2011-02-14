package Games::Lacuna::Task::Role::Client;

use 5.010;
use Moose::Role;

use Games::Lacuna::Task::Client;
use Try::Tiny;

my %CLIENTS;
our $DEFAULT_DIRECTORY = Path::Class::Dir->new($ENV{HOME}.'/.lacuna');

has 'database' => (
    is              => 'ro',
    isa             => 'Path::Class::Dir',
    coerce          => 1,
    documentation   => 'Path to the lacuna directory [Default '.$DEFAULT_DIRECTORY.']',
    default         => sub { return $DEFAULT_DIRECTORY },
    traits          => ['KiokuDB::DoNotSerialize','NoIntrospection'],
);

has 'client' => (
    is              => 'ro',
    isa             => 'Games::Lacuna::Task::Client',
    traits          => ['NoGetopt','KiokuDB::DoNotSerialize','NoIntrospection'],
    lazy_build      => 1,
);

sub _build_client {
    my ($self) = @_;
    
    my $database_stringify = $self->database->stringify;
    
    # See if we have client in cache
    if (defined $CLIENTS{$database_stringify}) {
        return $CLIENTS{$database_stringify};
    }
    
    my $database_file = Path::Class::File->new($self->database,'default.db');
    
    # Build new client
    my $client = Games::Lacuna::Task::Client->new(
        loglevel        => $self->loglevel,
        storage_file    => $database_file,
        debug           => 1,
    );
    
    $CLIENTS{$database_stringify} = $client;
    
    return $client;
}


sub paged_request {
    my ($self,%params) = @_;
    
    $params{params} ||= [];
    
    my $total = delete $params{total};
    my $data = delete $params{data};
    my $page = 1;
    my @result;
    
    PAGES:
    while (1) {
        push(@{$params{params}},$page);
        my $response = $self->request(%params);
        pop(@{$params{params}});
        
        foreach my $element (@{$response->{$data}}) {
            push(@result,$element);
        }
        
        if ($response->{$total} > (25 * $page)) {
            $page ++;
        } else {
            $response->{$data} = \@result;
            return $response;
        }
    }
}

sub request {
    my ($self,%params) = @_;
    
    my $method = delete $params{method};
    my $object = delete $params{object};
    my $params = delete $params{params} || [];
    
    $self->log('debug',"Run external request %s->%s",ref($object),$method);
    
    my $response;
    my $retry = 1;
    
    while ($retry) {
        $retry = 0;
        try {
            $response = $object->$method(@$params);
        } catch {
            my $error = $_;
            if (blessed($error)
                && $error->isa('LacunaRPCException')) {
                given ($error->code) {
                    when(1006) {
                        $self->log('debug','Session expired unexpectedly');
                        $self->client->reset_client();
                        $self->client->storage->delete('session');
                        $self->client->login;
                        $retry = 1;
                    }
                    when(1004) {
                        $self->log('error','Password incorrect');
                        $self->client->get_config_from_user();
                        $self->client->reset_client;
                        $retry = 1;
                    }
                    default {
                        $error->rethrow;
                    }
                }
            } else {
                die($error);
            }
        };
    }
    
    my $status = $response->{status} || $response;
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
    if ($response->{buildings}) {
        $self->write_cache(
            key     => 'body/'.$status->{body}{id}.'/buildings',
            value   => $response->{buildings},
            max_age => 600,
        );
    }
    
    return $response;
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

=encoding utf8

=head1 NAME

Games::Lacuna::Role::Client - Basic methods to access the Lacuna API

=head1 ACCESSORS

=head2 database

Path to the database directory.

=head2 client

L<Games::Lacuna::Task::Client> object

=head1 METHODS

=head2 request

Runs a request, caches the response and returns the response.

 my $response =  $self->request(
    object  => Games::Lacuna::Client::* object,
    method  => Method name,
    params  => [ Params ],
 );

=head2 paged_request

Runs a paged request (eg. list all trades)

 my $response =  $self->paged_request(
    object  => Games::Lacuna::Client::* object,
    method  => Method name,
    params  => [ Params ],
    total   => Field containing the number of items,
    data    => Data field,
 );

=head2 lookup_cache

Fetches the value with the given key from the cache.

 my $value = $self->lookup_cache($key);

=head2 write_cache

Writes a value to the cache.

 $self->write_cache(
    key     => Cache key,
    data    => Data,
    max_age => Max cache age (optional),
 );

=head2 clear_cache

Removes a value from the cache

 $self->clear_cache($key);

=cut

no Moose::Role;
1;
