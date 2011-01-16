package Games::Lacuna::Task::Role::Notify;

use 5.010;
use Moose::Role;

use MIME::Lite;

has 'email' => (
    is              => 'rw',
    isa             => 'Str',
    documentation   => q[Notification e-mail address],
    required        => 1,
);

has 'email_send' => (
    is              => 'rw',
    isa             => 'ArrayRef',
    default         => sub { [] },
    documentation   => q[e-mail send methods],
);

sub notify {
    my ($self,$subject,$message) = @_;
    
    my $email = MIME::Lite->new(
        From    => $self->email,
        To      => $self->email,
        Subject => $subject,
        Type    => 'TEXT',
        Data    => $message,
    );
    
    $email->send( @{ $self->email_send } );

}

no Moose::Role;
1;
