package Games::Lacuna::Task::Role::Inbox;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;

sub inbox_callback {
    my ($self,$callback,%params) = @_;
    
    $params{archive} ||= 0;
    $params{delete} ||= 0;
    if (defined $params{tags}
        && ref($params{tags}) eq '') {
        $params{tags} = [$params{tags}];
    }
    
    my $inbox_object = $self->build_object('Inbox');
    my $page_number = 1;
    my @messages;
    
    INBOX:
    while (1) {
        my $inbox_data = $self->request(
            object  => $inbox_object,
            method  => 'view_inbox',
            params  => [{ 
                page_number => $page_number, 
                ($params{tags} ? (tags => $params{tags}):())
            }],
        );
        
        foreach my $message (@{$inbox_data->{messages}}) {
            next
                unless $message->{from_id} == $message->{to_id};
            my $type;
            
            my $return = $callback->($message);
            
            if ($return) {
                push(@messages,$message)
            }
        }
        
        last INBOX
            if scalar(@{$inbox_data->{messages}}) < 25;
        
        $page_number++;
    }
    
    if (scalar(@messages)) {
        if ($params{archive}) {
            $self->log('notice',"Archiving %i messages",scalar @messages);
            $self->request(
                object  => $inbox_object,
                method  => 'archive_messages',
                params  => [( map { ref($_) ? $_->{id} : $_ } @messages )],
            );
        } elsif ($params{delete}) {
            $self->log('notice',"Deleting %i messages",scalar @messages);
            $self->request(
                object  => $inbox_object,
                method  => 'trash_messages',
                params  => [( map { ref($_) ? $_->{id} : $_ } @messages )],
            );
        }
    }
    
    return @messages;
}

sub inbox_read {
    my ($self,$message_id) = @_;
    
    my $inbox_object = $self->build_object('Inbox');
    
    # Get message
    my $response = $self->request(
        object  => $inbox_object,
        method  => 'read_message',
        params  => [$message_id],
    );
    
    my $message_data = $response->{message};
    
    if ($message_data->{body} =~ m/\{Starmap\s(?<x>-*\d+)\s(?<y>-*\d+)\s(?<body_name>[^}]+)\}/) {
        $message_data->{starmap} = {
            x       => $+{x},
            y       => $+{y},
            name    => $+{body_name},
        };
    }
    
    if ($message_data->{body} =~ m/\{Empire\s(?<empire_id>\d+)\s(?<empire_name>[^}]+)}/) {
        $message_data->{empire} = {
            id      => $+{empire_id},
            name    => $+{empire_name},
        };
    }
    
    return $message_data;
}

no Moose::Role;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Role::Inbox - Helper methods for inbox handling

=head1 SYNOPSIS

 package Games::Lacuna::Task::Action::MyTask;
 use Moose;
 extends qw(Games::Lacuna::Task::Action);
 with qw(Games::Lacuna::Task::Role::Inbox);

=head1 DESCRIPTION

This role provides inbox-related helper methods.

=head1 METHODS

=cut