# ============================================================================
package Games::Lacuna::Task;
# ============================================================================

use 5.010;
use version;
our $AUTHORITY = 'cpan:MAROS';
our $VERSION = version->new("1.00");

use Moose;
use Try::Tiny;
use Games::Lacuna::Task::Types;

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger
    MooseX::Getopt);

has 'task'  => (
    is              => 'ro',
    isa             => 'ArrayRef[Str]',
    required        => 1,
    documentation   => q[Select whick tasks to run],
);

has '+database' => (
    required        => 1,
);

our $WIDTH = 62;

sub run {
    my ($self) = @_;
    
    my $client = $self->client();
    
    # Call lazy builder
    $client->client;
    
    my $empire_name = $self->lookup_cache('config')->{name};
    
    $self->log('info',("=" x $WIDTH));
    $self->log('info',"Running tasks for empire %s",$empire_name);
    
    TASK:
    foreach my $task (@{$self->task}) {
        $self->log('info',("-" x $WIDTH));
        $self->log('info',"Running task %s",$task);
        my $element = join('',map { ucfirst(lc($_)) } split(/_/,$task));
        my $class = 'Games::Lacuna::Task::Action::'.$element;
        my $ok = 1;
        try {
            Class::MOP::load_class($class);
        } catch {
            $self->log('error',"Could not load tasks %s",$class,);
            $self->log('debug',"%s",$_);
            $ok = 0;
        };
        if ($ok) {
            my $task = $class->new(
                client  => $client,
                loglevel=> $self->loglevel,
            );
            $task->run;
        }
    }
    $self->log('info',("=" x $WIDTH));
}

1;