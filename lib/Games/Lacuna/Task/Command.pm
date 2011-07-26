# ============================================================================
package Games::Lacuna::Task::Command;
# ============================================================================

use 5.010;

use Moose;

use Games::Lacuna::Task::Types;
use Games::Lacuna::Task::Meta::Attribute::Trait::NoIntrospection;

use Games::Lacuna::Task::Utils qw(class_to_name);
use Try::Tiny;

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger
    Games::Lacuna::Task::Role::Introspect
    MooseX::Getopt);

has '+database' => (
    required        => 1,
);

sub execute {
    my ($self) = @_;
    
    $self->loglevel('debug')
        if $self->debug;
    
    my $client = $self->client();
    
    # Call lazy builder
    $client->client;
    
    my $command_name = class_to_name($self);
    my $empire_name = $self->lookup_cache('config')->{name};
    
    $self->log('notice',("=" x ($Games::Lacuna::Task::Constants::WIDTH - 8)));
    $self->log('notice',"Running command %s for empire %s",$command_name,$empire_name);
    
    try {
        local $SIG{TERM} = sub {
            $self->log('warn','Aborted by user');
            die('ABORT');
        };
        local $SIG{__WARN__} = sub {
            my $warning = $_[0];
            chomp($warning)
                unless ref ($warning); # perl 5.14 ready
            $self->log('warn',$warning);
        };
        
#        if ($self->call_info) {
#            $self->log('notice',"Info for command %s",$command_name);
#            $self->inspect($self);
#        } else {
#        }
        $self->run();
    } catch {
        $self->log('error',"An error occured while processing command %s: %s",$command_name,$_);
    };
    
    $self->log('notice',("=" x ($Games::Lacuna::Task::Constants::WIDTH - 8)));
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;