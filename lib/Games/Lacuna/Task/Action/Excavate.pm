package Games::Lacuna::Task::Action::Excavate;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;
no if $] >= 5.017004, warnings => qw(experimental::smartmatch);

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars
    Games::Lacuna::Task::Role::Ships
    Games::Lacuna::Task::Role::PlanetRun
    Games::Lacuna::Task::Role::Storage);

use List::Util qw(sum);
use Games::Lacuna::Client::Types qw(ore_types);

has 'min_ore' => (
    is              => 'rw',
    isa             => 'Int',
    documentation   => 'Only select bodies with mininimal ore quantities [Default 4000]',
    default         => 4000,
    required        => 1,
);

has 'ores' => (
    is              => 'rw',
    isa             => 'HashRef[Num]',
    traits          => ['Hash','NoGetopt'],
    required        => 1,
    handles         => {
        get_ore         => 'get',
    },
    lazy_build      => 1,
);

has 'excavated_bodies' => (
    is              => 'rw',
    isa             => 'ArrayRef[Int]',
    traits          => ['Array','NoGetopt'],
    handles         => {
        add_excavated_body => 'push',
    }
);

has 'spare_excavators' => (
    is              => 'rw',
    isa             => 'Int',
    documentation   => 'Ensure that spare excavators are available [Default 2]',
    default         => 2,
);

sub description {
    return q[Building and dispatch excavators to best suited bodies];
}

sub process_planet {}

sub _build_ores {
    my ($self) = @_;
    
    my $all_glyphs = $self->all_glyphs_stored;
    
    my $return = { map { $_ => 0 } ore_types() };
    my $ore_type_count = scalar ore_types();
    my $total_ores = sum(values %{$all_glyphs});
    while (my ($key,$value) = each %{$all_glyphs}) {
        $return->{$key} = (1/$ore_type_count) / ($value / $total_ores);
    }
    
    return $return;
}

sub run {
    my ($self) = @_;
    
    my %planets;
    
    foreach my $planet_stats ($self->get_planets) {
        $self->log('info',"Checking planet %s",$planet_stats->{name});
        my $available = $self->check_planet($planet_stats);
        
        if ($available) {
            $planets{$planet_stats->{id}} = $available;
        }
    }
    
    while (my ($key,$value) = each %planets) {
        my $planet_stats = $self->my_body_status($key);
        $self->dispatch_excavators($planet_stats,$value);
    }
    
    $self->log('debug',"Updating excavator cache");
    my $excavated = join(',',@{$self->excavated_bodies});
    $self->storage_do('UPDATE body SET is_excavated = 0 WHERE is_excavated = 1 AND id NOT IN ('.$excavated.')');
}

sub check_planet {
    my ($self,$planet_stats) = @_;
    
    # Get archaeology ministry
    my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
    
    return
        unless defined $archaeology_ministry;
    return
        unless $archaeology_ministry->{level} >= 11;
    
    my $archaeology_ministry_object = $self->build_object($archaeology_ministry);
    
    my $response = $self->request(
        object  => $archaeology_ministry_object,
        method  => 'view_excavators',
    );
    
    my $possible_excavators = $response->{max_excavators} - scalar @{$response->{excavators}} - 1 - $response->{travelling};
    
    # Get all excavated bodies
    foreach my $excavator (@{$response->{excavators}}) {
#        while (my ($key,$value) = each %{$excavator->{body}{ore}}) {
#            $self->ores->{$key} += $value * ($excavator->{glyph} / 100);
#        }
        next
            if $excavator->{id} == 0;
        
        $self->add_excavated_body($excavator->{body}{id});
    }
    
    return $possible_excavators;
}

sub dispatch_excavators {
    my ($self,$planet_stats,$possible_excavators) = @_;
    
    $self->log('info',"Process planet %s",$planet_stats->{name});
    
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'Space Port');
    
    return 
        unless defined $spaceport;
    
    my $spaceport_object = $self->build_object($spaceport);
    
    # Get available excavators
    my @avaliable_excavators = $self->get_ships(
        planet          => $planet_stats,
        quantity        => $possible_excavators + $self->spare_excavators,
        travelling      => 1,
        type            => 'excavator',
        build           => 1,
    );
    
    # Remove spare excavators from list
    my $ignore_excavators = scalar(@avaliable_excavators) - $possible_excavators;
    if ($ignore_excavators > 0) {
        for (1..$ignore_excavators) {
            pop(@avaliable_excavators);
        }   
    }
    
    # Check if we have available excavators
    return
        unless (scalar @avaliable_excavators);
    
    $self->log('debug','%i excavators available at %s',(scalar @avaliable_excavators),$planet_stats->{name});
    
    my @available_bodies;
    
    $self->search_stars_callback(
        sub {
            my ($star_data) = @_;
            
            my @possible_bodies;
            # Check all bodies
            foreach my $body (@{$star_data->{bodies}}) {
                # Check if solar system is inhabited by hostile empires
                return 1
                    if defined $body->{empire}
                    && $body->{empire}{alignment} =~ m/hostile/;
                
                # Check if body is inhabited
                next
                    if defined $body->{empire};
                
                # Check if already excavated
                next
                    if defined $body->{is_excavated}
                    && $body->{is_excavated};
                
                next
                    if $body->{id} ~~ $self->excavated_bodies;
                
                # Check body type
                next 
                    unless ($body->{type} eq 'asteroid' || $body->{type} eq 'habitable planet');
                
                my $total_ore = sum values %{$body->{ore}};
                
                # Check min ore
                next
                    if $total_ore < $self->min_ore;
                
                push(@possible_bodies,$body);
            }
            
            # All possible bodies
            foreach my $body (@possible_bodies) {
                my $weighted_ores = 0;
                foreach my $ore (keys %{$body->{ore}}) {
                    $weighted_ores += $body->{ore}{$ore} * $self->get_ore($ore);
                }
                
                push(@available_bodies,[ $weighted_ores, $body ]);
            }
            
            return 0
                if scalar @available_bodies > 50;

            return 1;
        },
        x           => $planet_stats->{x},
        y           => $planet_stats->{y},
        is_known    => 1,
        distance    => 1,
    );
    
    foreach my $body_data (sort { $b->[0] <=> $a->[0] } @available_bodies) {
        
        my $body = $body_data->[1];
        my $excavator = pop(@avaliable_excavators);
        
        return
            unless defined $excavator;
        
        $self->log('notice',"Sending excavator from %s to %s",$planet_stats->{name},$body->{name});
        
        $self->add_excavated_body($body->{id});
        
        # Send excavator to body
        my $response = $self->request(
            object  => $spaceport_object,
            method  => 'send_ship',
            params  => [ $excavator,{ "body_id" => $body->{id} } ],
            catch   => [
                [
                    1010,
                    qr/(already has an excavator from your empire or one is on the way|jurisdiction of the space station)/,
                    sub {
                        $self->log('debug',"Could not send excavator to %s",$body->{name});
                        push(@avaliable_excavators,$excavator);
                        return 0;
                    }
                ],
                [
                    1009,
                    qr/Can only be sent to asteroids and uninhabited planets/,
                    sub {
                        $self->log('debug',"Could not send excavator to %s",$body->{name});
                        push(@avaliable_excavators,$excavator);
                        return 0;
                    }
                ]
            ],
        );
        
        # Set body exacavated
        $self->set_body_excavated($body->{id});
    }
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::Excavate - Building and dispatch excavators to best suited bodies

=head1 DESCRIPTION

This task automatically builds and dispatches excavators to bodies in the
vincity. Bodies with scare ores are ranked higher than bodies with common
ores.

=cut
