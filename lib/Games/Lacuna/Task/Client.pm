package Games::Lacuna::Task::Client;

use 5.010;

use Moose;
with qw(Games::Lacuna::Task::Role::Logger);

use Games::Lacuna::Client;
use KiokuDB;
use Term::ReadKey;

our $API_KEY = '261cb463-cff4-458a-bbc6-807a6ff59d3e';
our $SERVER = 'https://us1.lacunaexpanse.com/';

has 'client' => (
    is              => 'rw',
    isa             => 'Games::Lacuna::Client',
    lazy_build      => 1,
    predicate       => 'has_client',
);

has 'storage_file' => (
    is              => 'ro',
    isa             => 'Path::Class::File',
    coerce          => 1,
    required        => 1,
);

has 'storage' => (
    is              => 'ro',
    isa             => 'KiokuDB',
    lazy_build      => 1,
);

has 'storage_scope' => (
    is              => 'rw',
    isa             => 'KiokuDB::LiveObjects::Scope',
);

sub _build_storage {
    my ($self) = @_;
    
    my $storage_file = $self->storage_file->stringify;
    unless (-e $storage_file) {
        $self->log('info',"Initializing storage file %s",$storage_file);
        #`sqlite3 --init $storage_file --batch`;
    }
    
    my $storage = KiokuDB->connect(
        'dbi:SQLite:dbname='.$storage_file,
        create          => 1,
        transactions    => 0,
    );
    
    my $scope = $storage->new_scope;
    $self->storage_scope($scope);
    
    return $storage;
}

sub _build_client {
    my ($self) = @_;
    
    my $storage = $self->storage;
    my $config = $storage->lookup('config');
    
    unless (defined $config) {
        my ($password,$name,$server,$api);
        
        $self->log('info',"Initializing local database");
        
        while (! defined $server || $server !~ m/https?:\/\//) {
            say "Please enter the server url (leave empty for default: '$SERVER'):";
            while ( not defined( $server = ReadLine(-1) ) ) {
                # no key pressed yet
            }
            chomp($server);
            $server ||= $SERVER;
        }
        
        say "Please enter the api key (leave empty for default: '$API_KEY'):";
        while ( not defined( $api = ReadLine(-1) ) ) {
            # no key pressed yet
        }
        chomp($api);
        $api ||= $API_KEY;
        
        while (! defined $name || $name =~ m/^\s*$/) {
            say 'Please enter the empire name:';
            while ( not defined( $name = ReadLine(-1) ) ) {
                # no key pressed yet
            }
            chomp($name);
        }
        
        while (! defined $password || $password =~ m/^\s*$/) {
            ReadMode 2;
            say 'Please enter the empire password:';
            while ( not defined( $password = ReadLine(-1) ) ) {
                # no key pressed yet
            }
            ReadMode 0;
            chomp($password);
        }
        
        $config = {
            password    => $password,
            name        => $name,
            api_key     => $api,
            uri         => $server,
        };
        
        $storage->store('config' => $config);
    }
    
    my $client = Games::Lacuna::Client->new(
        %{$config},
        session_persistent  => 1,
    );
    
    $client->assert_session();

    return $client;
}

after 'client' => sub {
    my ($self) = @_;
    my $client = $self->meta->get_attribute('client')->get_raw_value($self);
    my $config = $self->storage->lookup('config');
    
    if ($client && $client->session_id) {
        $config->{session_id} = $client->session_id;
        $config->{session_start} = $client->session_start;
        $self->storage->update($config);
    }
    
    return $client;
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;