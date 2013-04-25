package Games::Lacuna::Task::Action::ShipSend;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Stars',
    'Games::Lacuna::Task::Role::Ships',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['target_planet','home_planet'] };

use Games::Lacuna::Task::Utils qw(parse_ship_type);

has 'ship_type' => (
    is              => 'rw',
    isa             => 'Str',
    documentation   => "Ship type to send",
    required        => 1,
);

has 'count' => (
    is              => 'rw',
    isa             => 'Int',
    documentation   => "Number of ships to send",
    default         => 1,
);

sub description {
    return q[Send ships to another planet];
}

sub run {
    my ($self) = @_;
    my $planet_home = $self->home_planet_data();
    my $planet_target = $self->target_planet_hash();
    
    # Get spaceport
    my ($spaceport) = $self->find_building($planet_home->{id},'Spaceport');
    return $self->log('error','Could not find spaceport')
        unless (defined $spaceport);
    my $spaceport_object = $self->build_object($spaceport);
    
    # Get ships
    my @avaliable_ships = $self->get_ships(
        planet          => $planet_home,
        quantity        => $self->count,
        type            => parse_ship_type($self->ship_type),
        build           => 0,
        travelling      => 0,
    );
    
    
    my @send_ships = grep { defined } @avaliable_ships[0..$self->count];
    
    if (scalar @send_ships < $self->count) {
        $self->abort('Not enough ships available to send (%i)',$self->count);
    }
   
    my $response = $self->request(
        object      => $spaceport_object,
        method      => 'send_fleet',
        params      => [ \@send_ships,$planet_target],
    );
    
    $self->log('notice','Sent %i %s to %s',scalar(@send_ships),$self->ship_type,$response->{fleet}[0]{ship}{to}{name});
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::SpyFetch - Send spies to another planet

=head1 DESCRIPTION

This task manual task send a given number of spies to a selected planet

=cut