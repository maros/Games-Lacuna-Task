package Games::Lacuna::Task::Action::UpgradePlatform;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;
no if $] >= 5.017004, warnings => qw(experimental::smartmatch);

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Building',
    'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['start_building_at','orbit'] };

has '+min_orbit' => (
    traits => ['NoGetopt'],
);

has '+max_orbit' => (
    traits => ['NoGetopt'],
);


use List::Util qw(max min);
use Games::Lacuna::Task::Utils qw(parse_date);

sub description {
    return q[Upgrade terraforming and gas giant platforms if required];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $is_gas_giant = ($planet_stats->{type} eq 'gas giant') ? 1:0;
    my $is_orbit = ($planet_stats->{orbit} > $self->max_orbit
        || $planet_stats->{orbit} < $self->min_orbit) ? 1:0;
    
    return
        unless $is_gas_giant || $is_orbit;
    
    return
        if $planet_stats->{plots_available} > 5;
    
    my $build_queue_size = $self->build_queue_size($planet_stats->{id});
    
    # Check if build queue is filled
    return
        if ($build_queue_size > $self->start_building_at);
    
    my $max_plots = $planet_stats->{size};
    
    my $terraforming_total_level = 0;
    my $gasgiant_total_level = 0;
    my @terraforming_platforms;
    my @gasgiant_platforms;
    
    my @buildings = $self->buildings_body($planet_stats->{id});
    
    # Get baisc figures
    my $pantheon_level = 0;
    my $build_total_count = scalar @buildings;
    my $build_plot_count = $planet_stats->{building_count};
    my $build_glyph_count = $build_total_count - $build_plot_count;
    my $current_plots = $build_plot_count + $planet_stats->{plots_available};
    my $max_possible_plots = 11 * 11 - $build_glyph_count;

    # Find relevant buildings
    foreach my $building (@buildings) {
        given ($building->{url}) {
            when ('/pantheonofhagness') {
                $max_plots += $building->{level};
                $pantheon_level = $building->{level};
            }
            when ('/terraformingplatform') {
                $terraforming_total_level += $building->{level};
                if ($building->{pending_build}) {
                    $terraforming_total_level++;
                    $current_plots++
                };
                push(@terraforming_platforms,$building);
            }
            when ('/gasgiantplatform') {
                $gasgiant_total_level += $building->{level};
                if ($building->{pending_build}) {
                    $gasgiant_total_level++;
                    $current_plots++
                };
                push(@gasgiant_platforms,$building);
            }
        }
    }
    
    # Check max extra plots
    $max_plots = min($max_plots,$max_possible_plots);
    my $possible_extra_plots = $max_plots - $current_plots;
    
    return
        if ($possible_extra_plots == 0);
    
    # Upgrade gas giant platforms
    if ($is_gas_giant
        && ($is_orbit == 0 || $gasgiant_total_level <= $terraforming_total_level)) {
        foreach my $building (sort { $a->{level} <=> $b->{level} }
            @gasgiant_platforms) {
            $self->upgrade_building($planet_stats,$building);
            
            $build_queue_size++;
            last
                if $build_queue_size >= $self->start_building_at;
        }
    # Upgrade terraformin platforms
    } elsif ($is_orbit) {
        foreach my $building (sort { $a->{level} <=> $b->{level} }
            @terraforming_platforms) {
            $self->upgrade_building($planet_stats,$building);
            
            $build_queue_size++;
            last
                if $build_queue_size >= $self->start_building_at;
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::UpgradePlatform - Upgrade terraforming and gas giant platforms if required

=head1 DESCRIPTION

This task will upgrade gas giant and terraforming platforms if the
build queue is empty and additional plots are needed.

=cut