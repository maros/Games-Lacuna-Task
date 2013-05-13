package Games::Lacuna::Task::Action::ShipDestroyed;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars
    Games::Lacuna::Task::Role::Inbox);

sub description {
    return q[Checks the inbox for destroyed/shot down ships messages];
}

sub run {
    my ($self) = @_;
    
    my $page_number = 1;
    
    my @star_checked;

    $self->inbox_callback(sub {
            my ($message) = @_;
            my $type;
            
            given ($message->{subject}) {
                when ('Probe Destroyed') {
                    $type = 'probe';
                }
                when ('Probe Lost') {
                    $type = 'probe';
                }
                when ('Lost Contact With Probe') {
                    $type = 'probe';
                }
                when ('Ship Shot Down') {
                    $type = 'ship';
                }
                default {
                    return 0;   
                }
            }
            
            # Get message
            my $message_data = $self->inbox_read($message->{id});
                
            # Parse star id,x,y
            return 1
                unless $message_data->{starmap};
                
            my $body_name = $message_data->{starmap}{name};
            my $body_data = $self->get_body_by_xy($message_data->{starmap}{x},$message_data->{starmap}{y});
            
            my $star_data;
            if (defined $body_data) {
                $star_data = $self->get_star($message_data->{starmap}{id});
            } else {
                $star_data = $self->get_star_by_xy($message_data->{starmap}{x},$message_data->{starmap}{y});
            }
                
            return 1
                unless $star_data;
                
            unless ($star_data->{id} ~~ \@star_checked) {
                $self->_get_star_api($star_data->{id},$star_data->{x},$star_data->{y});
                push (@star_checked,$star_data->{id});
            }
            
            if ($type eq 'probe') {
                return 1
                    unless $message_data->{empire};
                $self->log('warn','A probe in the %s system was destroyed by %s',$body_name,$message_data->{empire}{name});
            } elsif ($type eq 'ship') {
                $self->log('warn','Our ship on way to %s was shot down',$body_name);
            }
            
            # TODO message
            
            return 1;
        },
        archive => 1,
    );
}

1;