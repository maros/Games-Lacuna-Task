package Games::Lacuna::TaskRunner;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task);
with qw(MooseX::Getopt);

use Games::Lacuna::Task::Utils qw(class_to_name name_to_class);
use Try::Tiny;

has 'exclude'  => (
    is              => 'rw',
    isa             => 'ArrayRef[Str]',
    documentation   => 'Select which tasks NOT to run [Multiple]',
    predicate       => 'has_exclude',
);

has 'task'  => (
    is              => 'rw',
    isa             => 'ArrayRef[Str]',
    documentation   => 'Select which tasks to run [Multiple, Default all]',
    predicate       => 'has_task',
);

has '+configdir' => (
    required        => 1,
);

sub run {
    my ($self) = @_;
    
    my $client = $self->client();
    
    # Call lazy builder
    $client->client;
    
    my $empire_name = $self->empire_name;
    
    $self->log('notice',("=" x ($Games::Lacuna::Task::Constants::SCREEN_WIDTH - 8)));
    $self->log('notice',"Running tasks for empire %s",$empire_name);
    
    my $global_config = $client->config->{global};
    
    $self->task($global_config->{task})
        if (defined $global_config->{task}
        && ! $self->has_task);
    $self->exclude($global_config->{exclude})
        if (defined $global_config->{exclude}
        && ! $self->has_exclude);
    
    my @tasks;
    if (! $self->has_task
        || 'all' ~~ $self->task) {
        @tasks = $self->all_actions;

    } else {
        foreach my $task (@{$self->task}) {
            my $class = name_to_class($task);
            push(@tasks,$class)
                unless $class ~~ \@tasks;
        }
    }
    
    # Loop all tasks
    TASK:
    foreach my $task_class (@tasks) {
        my $task_name = class_to_name($task_class);
        
        next
            if $self->has_exclude && $task_name ~~ $self->exclude;
        
        my $ok = 1;
        try {
            Class::MOP::load_class($task_class);
        } catch {
            $self->log('error',"Could not load task %s: %s",$task_class,$_);
            $ok = 0;
        };
        
        next
            if $task_class->meta->can('no_automatic')
            && $task_class->meta->no_automatic;
        
        if ($ok) {
            $self->log('notice',("-" x ($Games::Lacuna::Task::Constants::SCREEN_WIDTH - 8)));
            $self->log('notice',"Running action %s",$task_name);
            try {
                my $task_config = $client->task_config($task_name);
                my $task = $task_class->new(
                    %{$task_config}
                );
                $task->execute;
            } catch {
                $self->log('error',"An error occured while processing %s: %s",$task_class,$_);
            }
        }
    }
    $self->log('notice',("=" x ($Games::Lacuna::Task::Constants::SCREEN_WIDTH - 8)));
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;