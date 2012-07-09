package Games::Lacuna::Task::Action::VrbanskCombine;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun);
use List::Util qw(min max);

use Games::Lacuna::Client::Types qw(ore_types);

our @RECIPIES = (
    [qw(goethite halite gypsum trona)],
    [qw(gold anthracite uraninite bauxite)],
    [qw(kerogen methane sulfur zircon)],
    [qw(monazite fluorite beryl magnetite)],
    [qw(rutile chromite chalcopyrite galena)],
);

has 'keep_gylphs' => (
    isa             => 'Int',
    is              => 'rw',
    required        => 1,
    documentation   => 'Keep N-gylps in storage (do not combine them) [Default: 5]',
    default         => 5,
);

sub description {
    return q[Cobine glyphs to get Halls of Vrbansk plans];
}

sub process_planet {
    my ($self,$planet_stats) = @_;

    # Get archaeology ministry
    my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
    
    return
        unless defined $archaeology_ministry;

    # Get all glyphs
    my $archaeology_ministry_object = $self->build_object($archaeology_ministry);
    my $gylph_data = $self->request(
        object  => $archaeology_ministry_object,
        method  => 'get_glyph_summary',
    );

    my $available_gylphs = { map { $_ => 0 } ore_types() };
    
    foreach my $glyph (@{$gylph_data->{glyphs}}) {
        $available_gylphs->{$glyph->{type}} = $glyph->{quantity} - $self->keep_gylphs;
    }

    # Get possible recipies
    RECIPIES: 
    foreach my $recipie (@RECIPIES) {
        
        while (1) {
            my (@recipie);
            
            foreach my $glyph (@{$recipie}) {
                next RECIPIES
                    unless $available_gylphs->{$glyph};
                push(@recipie,$available_gylphs->{$glyph});
            }
            
            my $quantity = min(@recipie,50);
            
            next RECIPIES
                unless $quantity > 0;
            
            foreach my $glyph (@{$recipie}) {
                $available_gylphs->{$glyph} -= $quantity;
            }
            
            $self->log('notice','Combining %i glyphs %s',$quantity,join(', ', @{$recipie}));
                       
            $self->request(
                object  => $archaeology_ministry_object,
                method  => 'assemble_glyphs',
                params  => [$recipie,$quantity],
            );
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::VrbanskCombine - Combine glyphs to get Halls of Vrbansk plans

=head1 DESCRIPTION

This task will combine all available glyphs to create Halls of Vrbansk plans,
leaving a defined quantity of each glyph untouched.

=cut