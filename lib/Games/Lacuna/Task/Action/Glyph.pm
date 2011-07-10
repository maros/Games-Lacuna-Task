package Games::Lacuna::Task::Action::Glyph;

use 5.010;

use Games::Lacuna::Client::Types qw(ore_types)

use Moose;
extends qw(Games::Lacuna::Task::Action);

has 'recipies' => (
    isa             => 'ArrayRef[ArrayRef[Lacuna::Task::Type::Ore]]',
    is              => 'rw',
    documentation   => 'List of glyph recipies',
    required        => 1,
    default         => sub {
        return [
            [qw(goethite halite gypsum trona)],
            [qw(gold anthracite uraninite bauxite)],
            [qw(kerogen methane sulfur zircon)],
            [qw(monazite fluorite beryl magnetite)],
            [qw(rutile chromite chalcopyrite galena)],
        ]    
    }
);

has 'keep_gylphs' => (
    isa             => 'Int',
    is              => 'rw',
    required        => 1,
    documentation   => 'Keep N-gylps in storage (do not combine them)',
    default         => 5,
);

sub description {
    return q[This task automates the combination of glyphs];
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
        method  => 'get_glyphs',
    );

    my $available_gylphs = { map { $_ => [] } ore_types() };
    
    foreach my $glyph (@{$gylph_data->{glyphs}}) {
        push(@{$available_gylphs->{$glyph->{type}}},$glyph->{id});
    }

    # Sutract keep_glyphs
    foreach my $glyph (keys %$available_gylphs) {
        for (1..$self->keep_gylphs) {
            pop(@{$available_gylphs->{$glyph}});
        }
    }
    
    # Get possible recipies
    RECIPIES: 
    foreach my $recipie (@{$self->recipies}) {
        while (1) {
            my (@recipie,@recipie_name);
            foreach my $glyph (@{$recipie}) {
                next RECIPIES
                    unless scalar @{$available_gylphs->{$glyph}};
            }
            foreach my $glyph (@{$recipie}) {
                push(@recipie_name,$glyph);
                push(@recipie,pop(@{$available_gylphs->{$glyph}}));
            }
             
            $self->log('notice','Combining glyphs %s',join(', ',@recipie_name));
                       
            $self->request(
                object  => $archaeology_ministry_object,
                method  => 'assemble_glyphs',
                params  => [\@recipie],
            );
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__



