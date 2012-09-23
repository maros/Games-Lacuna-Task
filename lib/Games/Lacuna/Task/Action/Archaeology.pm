package Games::Lacuna::Task::Action::Archaeology;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun
    Games::Lacuna::Task::Role::Storage);

use List::Util qw(max sum);
use Games::Lacuna::Client::Types qw(ore_types);
use Games::Lacuna::Task::Utils qw(parse_date);

sub description {
    return q[Search for glyphs via Archaeology Ministry];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $all_glyphs = $self->all_glyphs_stored;
    
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

