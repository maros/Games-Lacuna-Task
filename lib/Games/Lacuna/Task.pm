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
use YAML qw(LoadFile);

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
    
    $self->log('notice',("=" x $WIDTH));
    $self->log('notice',"Running tasks for empire %s",$empire_name);
    
    my $database_dir = $self->database->dir;
    
    # Loop all tasks
    TASK:
    foreach my $task (@{$self->task}) {
        $self->log('notice',("-" x $WIDTH));
        $self->log('notice',"Running task %s",$task);
        my $element = join('',map { ucfirst(lc($_)) } split(/_/,$task));
        my $class = 'Games::Lacuna::Task::Action::'.$element;
        
        my $task_config = {};
        my $task_config_file = Path::Class::File->new($database_dir,lc($task).'.yml');
        if (-e $task_config_file) {
            $self->log('debug',"Loading task %s config from",$task,$task_config_file);
            $task_config = LoadFile($task_config_file->stringify);
        }
        
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
                %{$task_config},
                client  => $client,
                loglevel=> $self->loglevel,
            );
            $task->run;
        }
    }
    $self->log('notice',("=" x $WIDTH));
}

1;