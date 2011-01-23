# ============================================================================
package Games::Lacuna::Task;
# ============================================================================

use 5.010;
use version;
our $AUTHORITY = 'cpan:MAROS';
our $VERSION = version->new("1.00");

use Games::Lacuna::Task::Types;
use Games::Lacuna::Task::Meta::Attribute::Trait::NoIntrospection;

use Moose;
use Try::Tiny;
use YAML qw(LoadFile);

use Module::Pluggable 
    search_path => ['Games::Lacuna::Task::Action'],
    sub_name => 'all_tasks';

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger
    MooseX::Getopt);

has 'config' => (
    is              => 'ro',
    isa             => 'HashRef',
    traits          => ['NoGetopt'],
    lazy_build      => 1,
);

has 'task'  => (
    is              => 'ro',
    isa             => 'ArrayRef[Str]',
    documentation   => 'Select which tasks to run [Multiple]',
    predicate       => 'has_task',
);

has 'task_info'  => (
    is              => 'ro',
    isa             => 'Bool',
    default         => 0,
    documentation   => 'Show task info and configuration',
);

has '+database' => (
    required        => 1,
);

our $WIDTH = 62;

sub _build_config {
    my ($self) = @_;
    
    my $database_dir = $self->database->dir;
    
    # Get global config
    my $global_config = {};
    
    foreach my $file (qw(lacuna config default)) {
        my $global_config_file = Path::Class::File->new($database_dir,$file.'.yml');
        if (-e $global_config_file) {
            $self->log('debug',"Loading config from %s",$global_config_file);
            $global_config = LoadFile($global_config_file->stringify);
            last;
        }
    }
    
    return $global_config;
}

sub task_config {
    my ($self,$task) = @_;
    return $self->config->{$task} || {};
}

sub run {
    my ($self) = @_;
    
    my $client = $self->client();
    
    # Call lazy builder
    $client->client;
    
    my $empire_name = $self->lookup_cache('config')->{name};
    
    $self->log('notice',("=" x $WIDTH));
    $self->log('notice',"Running tasks for empire %s",$empire_name);
    
    my @tasks;
    if (! $self->has_task
        || 'all' ~~ $self->task) {
        @tasks = __PACKAGE__->all_tasks;
    } else {
        foreach my $task (@{$self->task}) {
            my $element = join('',map { ucfirst(lc($_)) } split(/_/,$task));
            my $class = 'Games::Lacuna::Task::Action::'.$element;
            push(@tasks,$class)
                unless $class ~~ \@tasks;
        }
    }
    
    # Loop all tasks
    TASK:
    foreach my $task_class (@tasks) {
        my $task_name = $task_class;
        $task_name =~ s/^.+::([^:]+)$/$1/;
        $task_name = lc($task_name);
        
        $self->log('notice',("-" x $WIDTH));
        
        my $ok = 1;
        try {
            Class::MOP::load_class($task_class);
        } catch {
            $self->log('error',"Could not load task %s: %s",$task_class,$_);
            $ok = 0;
        };
        if ($ok) {
            try {
                if ($self->task_info) {
                    $self->log('notice',"Info for task %s",$task_name);
                    my $task_meta = $task_class->meta;
                    
                    $self->log('info',$task_class->description);
                    
                    my @attributes;
                    foreach my $attribute ($task_meta->get_all_attributes) {
                        next
                            if $attribute->does('NoIntrospection');
                        push (@attributes,$attribute);
                    }
                    if (scalar @attributes) {
                        $self->log('info','Available configuration options for task %s',$task_name);
                        foreach my $attribute (@attributes) {
                            $self->log('info',"- %s",$attribute->name);
                            if ($attribute->has_documentation) {
                                $self->log('info',"  Desctiption: %s",$attribute->documentation);
                            }
                            if ($attribute->is_required) {
                                $self->log('info',"  Is required");
                            }
                            if ($attribute->has_type_constraint) {
                                $self->log('info',"  Type: %s",$attribute->type_constraint->name);
                            }
                            if ($attribute->has_default) {
                                my $default = $attribute->default;
                                $default = $default->()
                                    if (ref($default) eq 'CODE');
                                $self->log('info',"  Default: %s",_pretty_dump($default));
                            }
                            my $current_config = $self->task_config($task_name);
                            if (exists $current_config->{$attribute->name}) {
                                $self->log('info',"  Current configtation: %s",_pretty_dump($current_config->{$attribute->name}));
                            }
                        }
                    } else {
                        $self->log('info','Task %s does not take any options',$task_name);
                    }
                } else {
                    $self->log('notice',"Running task %s",$task_name);
                    my $task = $task_class->new(
                        %{$self->task_config($task_name)},
                        client  => $client,
                        loglevel=> $self->loglevel,
                    );
                    $task->run;
                } 
                
            } catch {
                $self->log('error',"An error occured while processing %s: %s",$task_class,$_);
            }
        }
    }
    $self->log('notice',("=" x $WIDTH));
}

sub _pretty_dump {
    my $dump = Data::Dumper::Dumper($_[0]);
    chomp($dump);
    $dump =~ s/^\$VAR1\s=\s(.+);$/$1/s;
    return $dump;
}


=encoding utf8

=head1 NAME

Games::Lacuna::Task - Automation framework for the Lacuna Expanse MMOPG

=head1 SYNOPSIS

    my $task   = Games::Lacuna::Task->new(
        task    => ['recycle','repair'],
        config  => {
            recycle => ...
        },
    );
    $task->run();

or via commandline (see bin/lacuna_task)

=head1 DESCRIPTION

This module provides a framework for implementing various automation tasks for
the Lacuna Expanse. It provides 

=over

=item * a way of customizing which tasks to run in which order

=item * a logging mechanism

=item * configuration handling

=item * storage (KiokuDB)

=item * simple access to the Lacuna API (via Games::Lacuna::Client)

=item * many useful helper methods and roles

=cut

__PACKAGE__->meta->make_immutable;
no Moose;
1;