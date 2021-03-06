package Games::Lacuna::Task::Action::FissureRemote;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;
no if $] >= 5.017004, warnings => qw(experimental::smartmatch);

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Stars',
    'Games::Lacuna::Task::Role::Inbox',
    'Games::Lacuna::Task::Role::Ships',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['home_planet'] };

use List::Util qw(max sum);

has 'sealer_count' => (
    is              => 'rw',
    isa             => 'Int',
    default         => 3,
    documentation   => q[Number of fissure sealers to send to each fissure],
);

sub description {
    return q[Downgrade fissures on remote planets];
}

sub run {
    my ($self) = @_;
    
    my $planet_home = $self->home_planet_data();
    
    # Get spaceport
    my ($spaceport) = $self->find_building($planet_home->{id},'Spaceport');
    return $self->log('error','Could not find spaceport')
        unless (defined $spaceport);
    my $spaceport_object = $self->build_object($spaceport);
    
    
    $self->inbox_callback(sub {
            my ($message) = @_;
            
            return 0
                unless ($message->{subject} ~~ ['Fissure Spawns in neighborhood','Fissure growing nearby','Nearby planet about to explode']);
            
            my $message_data = $self->inbox_read($message->{id});
            my $body_data = $self->get_body_by_xy($message_data->{starmap}{x},$message_data->{starmap}{y});
            
            return 1
                unless defined $body_data;
            
            return 1
                if defined $body_data->{empire}
                || $body_data->{type} eq 'asteroid';
                            
            # Get available fissure sealer ships
            my @avaliable_fissure_sealer = $self->get_ships(
                planet          => $planet_home,
                quantity        => $self->sealer_count,
                type            => 'fissure_sealer',
            );
            
            return 0
                unless scalar @avaliable_fissure_sealer == $self->sealer_count;
            
            
            my $response = $self->request(
                object      => $spaceport_object,
                method      => 'send_fleet',
                params      => [ \@avaliable_fissure_sealer,{ 'body_id' => $body_data->{id} }],
                catch   => [
                    [
                        1013,
                        qr/Can only be sent to uninhabited planets/,
                        sub {
                             return 0;
                        }
                    ],
                    [
                        1009,
                        qr/Can only be sent to planets/,
                        sub {
                             return 0;
                        }
                    ],
                ],
            );
            
            $self->log('notice','Sent %i fissure sealers to %s',3,$response->{fleet}[0]{ship}{to}{name})
                if defined $response;
            
            return 1;
        },
        tags    => 'Fissure',
        archive => 1,
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::Fissure - Downgrade fissures

=head1 DESCRIPTION

This task will automate the downgrade and demoloition of fissures.

=cut

