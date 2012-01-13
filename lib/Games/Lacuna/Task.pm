# ============================================================================
package Games::Lacuna::Task;
# ============================================================================

use 5.010;

our $AUTHORITY = 'cpan:MAROS';
our $VERSION = "2.00";

use Moose;
extends qw(Games::Lacuna::Task::Base);
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



=encoding utf8

=head1 NAME

Games::Lacuna::Task - Automation framework for the Lacuna Expanse MMPOG

=head1 SYNOPSIS

    my $task   = Games::Lacuna::Task->new(
        task    => ['recycle','repair'],
        config  => {
            recycle => ...
        },
    );
    $task->run();

or via commandline (see L<bin/lacuna_task> and L<bin/lacuna_run>) 

=head1 DESCRIPTION

This module provides a framework for implementing various automation tasks for
the Lacuna Expanse MMPOG. It provides 

=over

=item * a way of customizing which tasks to run in which order

=item * a convinient command line interface

=item * a logging mechanism

=item * configuration handling

=item * cache for increasing speed and reducing rpc calls

=item * simple access to the Lacuna API (via Games::Lacuna::Client)

=item * many useful helper methods and roles

=back

=head CONFIGURATION

Games::Lacuna::Task uses a yaml configuration file which is loaded from the
database directory (defaults to ~/.lacuna). The filename should be config.yml
or lacuna.yml.

Example config.yml

 ---
 connect:
   name: "empire_name"          
   password: "empire_password"  
   uri: "http://..."            # optional
   api_key: "a1f9...."          # optional
 global:
   task: 
     - excavate
     - bleeder
     - repair
     - dispose
   dispose_percentage: 80
 excavate: 
   excavator_count: 3

The data of the configuration file must be a hash with hash keys corresponding
to the lowecase task names. The hash key 'global' should be used for
global settings.

global.task specifies which tasks should be run by default and is only used
if no tasks have been set explicitly (e.g. via command line).

global.exclude specifies which tasks should be skipped default and is only 
used if no tasks have been set explicitly or via config.

global.exclude_planet and *.exclude_planet can be used to exclude certain
bodies from being processed.

All other values in the global section are used as default values for tasks.
(e.g. the 'dispose_percentage' setting can be used by the WasteMonument and
the WasteDispose task)

Username, password, empire name, api key and server url must be stored under
the connect key in the config file.

=cut

__PACKAGE__->meta->make_immutable;
no Moose;
1;