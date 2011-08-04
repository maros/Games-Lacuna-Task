package Games::Lacuna::Task::Action;

use 5.010;

use Moose;

extends qw(Games::Lacuna::Task::Base);

with qw(Games::Lacuna::Task::Role::Helper
    MooseX::Getopt);

use Games::Lacuna::Task::Utils qw(class_to_name);
use Try::Tiny;

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
        $self->run();
    } catch {
        $self->log('error',"An error occured while processing action %s: %s",$command_name,$_);
    };
    
};


__PACKAGE__->meta->make_immutable;
no Moose;
1;
