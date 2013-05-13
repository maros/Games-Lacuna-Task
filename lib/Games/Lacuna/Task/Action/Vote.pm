package Games::Lacuna::Task::Action::Vote;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Inbox);

our $BUILDING_COORDINATES_RE = qr/\(-?\d+,-?\d+\)/;
our $NAME_RE = qr/[[:space:][:alnum:]]+/;

has 'accept_proposition' => (
    isa             => 'RegexpRef',
    is              => 'rw',
    required        => 1,
    documentation   => 'Propositions matching this regexp should accepted',
    default         => sub { qr/^( 
        (Upgrade|Install) \s $NAME_RE
        |
        Demolish \s (Dent|Bleeder)
        |
        Rename \s $NAME_RE
        |
        Repair \s $NAME_RE
        |
        Seize \s $NAME_RE
        |
        Members Only
        |
        Transfer \s Station
    )/xi },
);

has 'reject_proposition' => (
    isa             => 'RegexpRef',
    is              => 'rw',
    documentation   => 'Propositions matching this regexp should be rejected',
    predicate       => 'has_reject_proposition',
);

sub description {
    return q[Parliament voting based on rules];
}

sub run {
    my ($self) = @_;
    
    PLANETS:
    foreach my $body_stats ($self->my_stations) {
        $self->log('info',"Processing space station %s",$body_stats->{name});
        $self->process_space_station($body_stats);
    }
    
    $self->inbox_callback(sub {
            my ($message) = @_;
            if ($message->{subject} =~ m/^(Pass|Reject):\s+/
                || $message->{subject} =~ $self->accept_proposition
                || $message->{subject} =~ $self->reject_proposition) {
                return 1;
            };
            return 0;
        },
        tags    => ['Parliament'],
        delete  => 1,
    );
}

sub process_space_station {
    my ($self,$station_stats) = @_;
    
    # Get parliament ministry
    my ($parliament) = $self->find_building($station_stats->{id},'Parliament');
    return
        unless $parliament;
    my $parliament_object = $self->build_object($parliament);
    
    my $proposition_data = $self->request(
        object  => $parliament_object,
        method  => 'view_propositions',
    );
    
    PROPOSITION:
    foreach my $proposition (@{$proposition_data->{propositions}}) {
        next PROPOSITION
            if defined $proposition->{my_vote};
        
        my $vote;
        
        if ($proposition->{name} =~ $self->accept_proposition) {
            $vote = 1;
        } elsif ($self->has_reject_proposition
            && $proposition->{name} =~ $self->reject_proposition) {
            $vote = 0;
        } else {
            next PROPOSITION;
        }
        
        $self->log('notice','Voting %s on proposition %s',($vote ? 'Yes':'No'),$proposition->{name});
        
        $self->request(
            object  => $parliament_object,
            method  => 'cast_vote',
            params  => [$proposition->{id},$vote],
        );
    
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::Vote - Parliament vote script

=head1 DESCRIPTION

This task will automate parliament voting. This task requires the main
empire password and not just the sitter password to be used.

=cut