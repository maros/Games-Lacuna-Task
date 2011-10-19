package Games::Lacuna::Task::Cache;

use 5.010;

use Moose;
use Digest::MD5 qw(md5_hex);
use Data::Dumper qw();

our $MAXAGE = 3600; # One hour

has 'key' => (
    is              => 'ro',
    isa             => 'Str',
    required        => 1,
);

has 'value' => (
    is              => 'ro',
);

has 'max_age' => (
    is              => 'ro',
    isa             => 'Int',
    default         => sub { return time() + $MAXAGE },
);

sub is_valid {
    my ($self) = @_;
    
    if ($self->max_age < time()) {
        return 0;
    }
    return 1;
}

sub store {
    my ($self,$storage) = @_;
    
    $storage->delete($self->key);
    $storage->store($self->key => $self);
    
    return $self;
}

sub checksum {
    my ($self) = @_;
    
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Varname = '';
    my $string = $self->key.'::'.Data::Dumper::Dump($self->value);
    return md5_hex($string);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;