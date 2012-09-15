package Games::Lacuna::Task::Action::ShipDestroyed;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars);

sub description {
    return q[Checks the inbox for destroyed/shot down ships messages];
}

sub run {
    my ($self) = @_;
    
    my $inbox_object = $self->build_object('Inbox');
    
    my $inbox_data = $self->request(
        object  => $inbox_object,
        method  => 'view_inbox',
        params  => [{ tags => ['Spies','Probe'],page_number => 1 }],
    );
    
    die $inbox_data;
    
    my @star_checked;
    my @archive_messages;
    
    foreach my $message (@{$inbox_data->{messages}}) {
        warn $message;
        
        next
            unless $message->{from_id} == $message->{to_id};
        
        my $type;
        
        given ($message->{subject}) {
            when ('Probe Destroyed') {
                $type = 'probe';
            }
            when ('Lost Contact With Probe') {
                $type = 'probe';
            }
            when ('Ship Shot Down') {
                $type = 'ship';
            }
            default {
                next;   
            }
        }
        
        
        # Get message
        my $message_data = $self->request(
            object  => $inbox_object,
            method  => 'read_message',
            params  => [$message->{id}],
        );
            
        # Parse star id,x,y
        next
            unless $message_data->{message}{body} =~ m/\{Starmap\s(?<x>-*\d+)\s(?<y>-*\d+)\s(?<body_name>[^}]+)\}/;
            
        my $body_name = $+{body_name};
        my $body_data = $self->get_body_by_xy($+{x},$+{y});
        
        my $star_data;
        if (defined $body_data) {
            $star_data = $self->get_star($body_data->{star_id});
        } else {
            $star_data = $self->get_star_by_xy($+{x},$+{y});
        }
            
        next
            unless $star_data;
            
        unless ($star_data->{id} ~~ \@star_checked) {
            $self->_get_star_api($star_data->{id},$star_data->{x},$star_data->{y});
            push (@star_checked,$star_data->{id});
        }
        
        if ($type eq 'probe') {
            next
                unless $message_data->{message}{body} =~ m/{Empire\s(?<empire_id>\d+)\s(?<empire_name>[^}]+)}/;
                
            $self->log('warn','A probe in the %s system was destroyed by %s',$body_name,$+{empire_name});
        } elsif ($type eq 'ship') {
            $self->log('warn','Our ship on way to %s was shot down',$body_name);
        }
        
        push(@archive_messages,$message->{id});
    }
    
    # Archive
    if (scalar @archive_messages) {
        $self->log('notice',"Archiving %i messages",scalar @archive_messages);
        
        $self->request(
            object  => $inbox_object,
            method  => 'archive_messages',
            params  => [\@archive_messages],
        );
    }
}

1;