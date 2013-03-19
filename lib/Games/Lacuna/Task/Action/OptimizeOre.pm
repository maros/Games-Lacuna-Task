package Games::Lacuna::Task::Action::OptimizeOre;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Waste',
    'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::Storage',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['plan_for_hours'] };

use List::Util qw(sum min);
use Games::Lacuna::Client::Types qw(ore_types);

sub description {
    return q[Try to balance ore storage by dumping abundant ores];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get stored waste
    my $waste_stored = $planet_stats->{waste_stored};
    my $waste_capacity = $planet_stats->{waste_capacity};
    my $waste_hour = $planet_stats->{waste_hour};
    my $waste_possible = $waste_capacity - $waste_stored;
    $waste_possible -= $waste_hour * $self->plan_for_hours
        if $waste_hour > 0;
    
    # Get stored ore
    my $ore_stored = $planet_stats->{ore_stored};
    my $ore_capacity = $planet_stats->{ore_capacity};
    my $ore_filled = ($ore_stored / $ore_capacity) * 100;
    
    return
        if $waste_possible <= 0
        || $ore_filled < 99; 
    
    my $resources = $self->resources_stored($planet_stats);
    
    my %ores;
    my $production = 0;
    foreach my $ore (ore_types()) {
        $ores{$ore} = $resources->{$ore.'_stored'};
        $production += $resources->{$ore.'_hour'};
    }
    
    my $average = int(1.1 * $ore_stored / keys %ores);
    
    my %dump;
    foreach my $ore (keys %ores) {
        if ($ores{$ore} > $average) {
            $dump{$ore} = $ores{$ore} - $average;
        }
    }
    
    my $dump_percentage = min(($production * $self->plan_for_hours),$waste_possible) / sum(values %dump);
    
    my $storage_builiding = $self->find_building($planet_stats->{id},'OreStorage');
    my $storage_builiding_object = $self->build_object($storage_builiding);
    
    foreach my $ore (keys %dump) {
        my $quantity = int($dump{$ore}*$dump_percentage);
        $self->log('notice','Dumping %i %s on %s',$quantity,$ore,$planet_stats->{name});
        
        $self->request(
            object  => $storage_builiding_object,
            method  => 'dump',
            params  => [$ore,$quantity],
        );
    }
    
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::OptimizeOre - TODO

=head1 DESCRIPTION

TODO

=cut
