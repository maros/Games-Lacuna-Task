package Games::Lacuna::Task::Report::Fleet;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;

use List::Util qw(max min);

my %TRANSLATE = (
    hulk                        => ['Hulk','S'],
    hulk_huge                   => ['Hulk','H'],
    hulk_fast                   => ['Hulk','F'],

    sweeper                     => ['Sweeper'],
    
    fighter                     => ['Defense','F'],
    drone                       => ['Defense','D'],

    snark3                      => ['Snark','3'],
    snark2                      => ['Snark','2'],
    snark                       => ['Snark','1'],
    
    placebo                     => ['Placebo','1'],
    placebo2                    => ['Placebo','2'],
    placebo3                    => ['Placebo','3'],
    placebo4                    => ['Placebo','4'],
    placebo5                    => ['Placebo','5'],
    placebo6                    => ['Placebo','6'],
    
    excavator                   => ['Exvcavator'],

    observatory_seeker          => ['Attack','O'],
    security_ministry_seeker    => ['Attack','SM'],
    spaceport_seeker            => ['Attack','SP'],
    thud                        => ['Attack','T'],
    detonator                   => ['Attack','D'],
    bleeder                     => ['Attack','B'],

    gas_giant_settlement_ship   => ['Platform','G'],
    terraforming_platform_ship  => ['Platform','T'],
    mining_platform_ship        => ['Platform','M'],
    
    scow                        => ['Scow','S'],
    scow_fast                   => ['Scow','F'],
    scow_mega                   => ['Scow','M'],
    scow_large                  => ['Scow','L'],
    
    stake                       => ['Other','ST'],
    scanner                     => ['Other','SC'],
    short_range_colony_ship     => ['Other','SC'],
    colony_ship                 => ['Other','CO'],
    probe                       => ['Other','P'],
    space_station               => ['Other','SS'],
    surveyor                    => ['Other','SU'],
    fissure_sealer              => ['Other','FI'],
    
    galleon                     => ['Cargo','G'],
    cargo_ship                  => ['Cargo','C'],
    dory                        => ['Cargo','D'],
    barge                       => ['Cargo','B'],
    freighter                   => ['Cargo','F'],
    
    spy_shuttle                 => ['Spy','SS'],
    spy_pod                     => ['Spy','SP'],
    smuggler_ship               => ['Spy','SM'],
    
    supply_pod4                 => ['Supply','4'],
    supply_pod3                 => ['Supply','3'],
    supply_pod2                 => ['Supply','2'],
    supply_pod                  => ['Supply','1'],
);

my %CATEGORIES = map { $_->[0] => 1 } values %TRANSLATE;
#my @CATEGORIES = sort keys %CATEGORIES;

sub report_fleet {
    my ($self) = @_;
    
    my $table = Games::Lacuna::Task::Table->new(
        headline=> 'Fleet Report',
        columns => ['Planet', sort(keys %CATEGORIES), 'Free' ],
    );
    
    foreach my $planet_id ($self->my_planets) {
       $self->_report_fleet_body($planet_id,$table);
    }
    
    return $table;
}

sub _report_fleet_body {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    # Get mining ministry
    my @spaceports = $self->find_building($planet_stats->{id},'SpacePort');
    
    return
        unless scalar @spaceports;
    
    my $slots = 0;
    foreach my $spaceport (@spaceports) {
        $slots += $spaceport->{level} * 2;
    }
    
    my $spaceport_object = $self->build_object($spaceports[0]);
    
    # Get all available ships
    my $ships_data = $self->request(
        object  => $spaceport_object,
        method  => 'view_all_ships',
        params  => [ { no_paging => 1 } ],
    );
    
    my (%row,$ships);
    
    SHIPS:
    foreach my $ship (@{$ships_data->{ships}}) {
        $slots--;
        my $ship_type = $TRANSLATE{$ship->{type}} || ['Other','?'];
        if (defined $ship_type->[1]) {
            $ships->{$ship_type->[0]} ||= {};
            $ships->{$ship_type->[0]}{$ship_type->[1]} ||= 0;
            $ships->{$ship_type->[0]}{$ship_type->[1]}++;
        } else {
            $ships->{$ship_type->[0]} ||= 0;
            $ships->{$ship_type->[0]}++;
        }
    }
    
    foreach my $category (keys %CATEGORIES) {
        if (defined $ships->{$category}) {
            my @lines;
            if (ref $ships->{$category} eq 'HASH') {
                foreach my $type (keys %{$ships->{$category}}) {
                    push(@lines,$ships->{$category}{$type}.' ('.$type.')');
                }
            } else {
                push(@lines,$ships->{$category});
            }
            $row{lc($category)} = join("\n",@lines);
        } else {
            $row{lc($category)} = 0;  
        }
    }
    
    $table->add_row({
        planet          => $planet_stats->{name},
        free            => $slots,
        %row,        
    });
}

no Moose::Role;
1;