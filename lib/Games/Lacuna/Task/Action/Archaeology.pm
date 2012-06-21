package Games::Lacuna::Task::Action::Archaeology;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun);

use List::Util qw(max sum);
use Games::Lacuna::Client::Types qw(ore_types);
use Games::Lacuna::Task::Utils qw(parse_date);

sub description {
    return q[Search for glyphs via Archaeology Ministry];
}

sub all_glyphs {
    my ($self) = @_;
    
    # Fetch total glyph count from cache
    my $all_glyphs = $self->get_cache('glyphs');
    
    return $all_glyphs
        if defined $all_glyphs;
    
    # Set all glyphs to zero
    $all_glyphs = { map { $_ => 0 } ore_types() };
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->my_planets) {
        # Get archaeology ministry
        my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
        
        next
            unless defined $archaeology_ministry;
        
        # Get all glyphs
        my $archaeology_ministry_object = $self->build_object($archaeology_ministry);
        my $glyph_data = $self->request(
            object  => $archaeology_ministry_object,
            method  => 'get_glyphs',
        );
        
        foreach my $glyph (@{$glyph_data->{glyphs}}) {
            $all_glyphs->{$glyph->{type}} ||= 0;
            $all_glyphs->{$glyph->{type}} ++;
        }
    }
    
    # Write total glyph count to cache
    $self->set_cache(
        key     => 'glyphs',
        value   => $all_glyphs,
        max_age => (60*60*24),
    );
    
    return $all_glyphs;
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $all_glyphs = $self->all_glyphs;
    
    my $total_glyphs = sum(values %{$all_glyphs});
    my $max_glyphs = max(values %{$all_glyphs});
    my $timestamp = time();
    
    # Get archaeology ministry
    my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
    
    return
        unless defined $archaeology_ministry;
    
    # Check archaeology is busy
    if (defined $archaeology_ministry->{work}) {
        my $work_end = parse_date($archaeology_ministry->{work}{end});
        if ($work_end > $timestamp) {
            return;
        }
    }
    
    my $archaeology_ministry_object = $self->build_object($archaeology_ministry);
    
    # Get searchable ores
    my $archaeology_view = $self->request(
        object  => $archaeology_ministry_object,
        method  => 'view',
    );
    
    return
        if defined $archaeology_view->{building}{work}{seconds_remaining};
    
    
    # Get searchable ores
    my $archaeology_ores = $self->request(
        object  => $archaeology_ministry_object,
        method  => 'get_ores_available_for_processing',
    );
    

    my ($search_ore) = sort { $all_glyphs->{$a} <=> $all_glyphs->{$b} } 
        keys %{$archaeology_ores->{ore}};
    
    $self->log('notice',"Searching for %s glyph on %s",$search_ore,$planet_stats->{name});
    $self->request(
        object  => $archaeology_ministry_object,
        method  => 'search_for_glyph',
        params  => [$search_ore],
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::Archaeology - Search for glyphs via archaeology ministry

=head1 DESCRIPTION

This task will automate the search for rare glyphs via the archaeology 
ministry. It will always search for the rarest glyph.

=cut

