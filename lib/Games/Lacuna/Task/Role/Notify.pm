package Games::Lacuna::Task::Role::Notify;

use 5.010;
use Moose::Role;

has 'email' => (
    is              => 'rw',
    isa             => 'Str',
    documentation   => q[Notification e-mail address],
);

sub notify {
    my ($self,$subject,$message) = @_;
    
    warn 'NOT YET IMPLEMENTED!';
}

no Moose::Role;
1;
