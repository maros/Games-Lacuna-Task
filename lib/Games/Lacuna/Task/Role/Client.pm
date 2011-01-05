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


no Moose::Role;
1;