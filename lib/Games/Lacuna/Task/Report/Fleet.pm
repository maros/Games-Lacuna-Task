package Games::Lacuna::Task::Report::Fleet;

use 5.010;

use Moose::Role;

sub report_fleet {
    my ($self) = @_;
    
    my $table = Games::Lacuna::Task::Table->new(
        headline=> 'Fleet Report',
        columns => ['Planet','Count','Type','Task','Cargo','Speed','Stealth','Combat'],
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
    my $spaceport = $self->find_building($planet_stats->{id},'SpacePort');
    
    return
        unless $spaceport;
    
    my $spaceport_object = $self->build_object($spaceport);
    
    # Get all available ships
    my $ships_data = $self->request(
        object  => $spaceport_object,
        method  => 'view_all_ships',
        params  => [ { no_paging => 1 } ],
    );
    
    my %ships;
    
    SHIPS:
    foreach my $ship (@{$ships_data->{ships}}) {
        
        my $moniker = join('_',$ship->{type},$ship->{task},$ship->{speed},$ship->{stealth},$ship->{combat},$ship->{hold_size});
        
        $ships{$moniker} ||= {
            count       => 0,
            type        => $ship->{type_human},
            task        => $ship->{task},
            speed       => $ship->{speed},
            stealth     => $ship->{stealth},
            combat      => $ship->{combat},
            cargo       => $ship->{cargo},
        };
        $ships{$moniker}{count} ++;
    }
    
    foreach my $ship (sort { $a->{type} cmp $b->{type}  }  values %ships) {
        $table->add_row({
            planet          => $planet_stats->{name},
            %$ship
        });
    }
    
}

no Moose::Role;
1;