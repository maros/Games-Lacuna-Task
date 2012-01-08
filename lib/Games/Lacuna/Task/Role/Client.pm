package Games::Lacuna::Task::Role::Client;

use 5.010;
use Moose::Role;

use Games::Lacuna::Task::Client;

our $DEFAULT_DIRECTORY = Path::Class::Dir->new($ENV{HOME}.'/.lacuna');

has 'configdir' => (
    is              => 'rw',
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
    handles         => [qw(get_cache set_cache clear_cache request paged_request empire_name build_object storage_prepare storage_do get_environment set_environment)]
);

sub _build_client {
    my ($self) = @_;
    
    # Build new client
    my $client = Games::Lacuna::Task::Client->new(
        loglevel        => $self->loglevel,
        configdir       => $self->configdir,
    );
    
    return $client;
}

no Moose::Role;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Role::Client - Basic methods to access the Lacuna API

=head1 ACCESSORS

=head2 configdir

Path to the config directory.

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

Fetches all response elements from a paged method

 my $response =  $self->paged_request(
    object  => Games::Lacuna::Client::* object,
    method  => Method name,
    params  => [ Params ],
    total   => 'field storing the total number of items',
    data    => 'field storing the items',
 );

