package Games::Lacuna::Task::Client;

use 5.010;

use Moose;
with qw(Games::Lacuna::Task::Role::Logger);

use Games::Lacuna::Client;
use KiokuDB;
use Term::ReadKey;
use IO::Interactive qw(is_interactive);
use YAML::Any qw(LoadFile);
use Games::Lacuna::Task::Utils qw(name_to_class);

our $API_KEY = '6ca1d525-bd4d-4bbb-ae85-b925ed3ea7b7';
our $URI = 'https://us1.lacunaexpanse.com/';

has 'client' => (
    is              => 'rw',
    isa             => 'Games::Lacuna::Client',
    lazy_build      => 1,
    predicate       => 'has_client',
    clearer         => 'reset_client',
);

has 'configdir' => (
    is              => 'ro',
    isa             => 'Path::Class::Dir',
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

has 'config' => (
    is              => 'ro',
    isa             => 'HashRef',
    lazy_build      => 1,
);

sub _build_config {
    my ($self) = @_;
    
    # Get global config
    my $global_config = {};
    
    foreach my $file (qw(lacuna config default)) {
        my $global_config_file = Path::Class::File->new($self->configdir,$file.'.yml');
        if (-e $global_config_file) {
            $self->log('debug',"Loading config from %s",$global_config_file->stringify);
            $global_config = LoadFile($global_config_file->stringify);
            last;
        }
    }
    
    return $global_config;
}

sub task_config {
    my ($self,$task_name) = @_;
    
    my $task_class = name_to_class($task_name);
    my $config_task = $self->config->{$task_name} || $self->config->{lc($task_name)} || {};
    my $config_global = $self->config->{global} || {};
    
    my $config_final = {};
    foreach my $attribute ($task_class->meta->get_all_attributes) {
        my $attribute_name = $attribute->name;
        if ($attribute_name eq 'client') {
            $config_final->{'client'} //= $self;
        } else {
            $config_final->{$attribute_name} = $config_task->{$attribute_name}
                if defined $config_task->{$attribute_name};
            $config_final->{$attribute_name} //= $config_global->{$attribute_name}
                if defined $config_global->{$attribute_name};
            $config_final->{$attribute_name} //= $self->$attribute_name
                if $self->can($attribute_name);
        }
    }
    
    return $config_final;
}

sub _build_storage {
    my ($self) = @_;
    
    my $storage_file = Path::Class::File->new($self->configdir,'default.db');
    unless (-e $storage_file->stringify) {
        $self->log('info',"Initializing storage file %s",$storage_file->stringify);
        my $storage_dir = $self->configdir->stringify;
        unless (-e $storage_dir) {
            mkdir($storage_dir)
                or $self->log('error','Could not create storage directory %s: %s',$storage_dir,$!);
        }
        $storage_file->touch
            or $self->log('error','Could not create storage file %s: %s',$storage_file->stringify,$!);
    }
    
    my $storage = KiokuDB->connect(
        'dbi:SQLite:dbname='.$storage_file->stringify,
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

    my $config = $self->config->{connect} || $storage->lookup('config') || $self->get_config_from_user();
    my $session = $storage->lookup('session') || {};

    # Check session
    if (defined $session 
        && defined $session->{session_start}
        && $session->{session_start} + $session->{session_timeout} < time()) {
        $self->log('debug','Session %s has expired',$session->{session_id});
        $session = {};
    }
    
    # Aliases
    $config->{name} ||= delete $config->{empire}
        if defined $config->{empire};
    $config->{uri} ||= delete $config->{server}
        if defined $config->{server};
    
    # Defaults
    $config->{api_key} ||= $API_KEY;
    $config->{uri} ||= $URI;

    my $client = Games::Lacuna::Client->new(
        %{$config},
        %{$session},
        session_persistent  => 1,
    );

    return $client;
}

sub get_config_from_user {
    my ($self) = @_;
    my ($password,$name,$server,$api);
    
    unless (is_interactive()) {
        die('Could not initialize config since we are not running in interactive mode');
    }

    $self->log('info',"Initializing local database");
    
    while (! defined $server || $server !~ m/^https?:\/\//) {
        say "Please enter the server url (leave empty for default: '$URI'):";
        while ( not defined( $server = ReadLine(-1) ) ) {
            # no key pressed yet
        }
        chomp($server);
        $server ||= $URI;
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
    
    my $config = {
        password    => $password,
        name        => $name,
        api_key     => $api,
        uri         => $server,
    };
    
    my $storage = $self->storage;
    $storage->delete('config');
    $storage->store('config' => $config);
    return $config;
}

sub login {
    my ($self) = @_;
    
    my $config = $self->storage->lookup('config');
    $self->client->name($config->{name});
    $self->client->password($config->{password});
    $self->client->api_key($config->{api_key});
    $self->client->empire->login($config->{name}, $config->{password}, $config->{api_key});
    $self->_update_session;
}

sub _update_session {
    my ($self) = @_;
    
    my $client = $self->meta->get_attribute('client')->get_raw_value($self);

    return
        unless defined $client && $client->session_id;

    my $session = $self->storage->lookup('session') || {};
    
    return $client
        if defined $session->{session_id} && $session->{session_id} ne $client->session_id;

    $self->log('debug','New session %s',$session->{session_id});

    $session->{session_id} = $client->session_id;
    $session->{session_start} = $client->session_start;
    $session->{session_timeout} = $client->session_timeout;
    $session->{session_start} = $client->session_start;
    
    $self->storage->delete('session');
    $self->storage->store('session' => $session);
    
    return $client;
}

after 'client' => sub {
    my ($self) = @_;
    return $self->_update_session();
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;
