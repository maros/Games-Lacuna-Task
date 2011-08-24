package Games::Lacuna::Task::Report::Incoming;

use 5.010;

use Moose::Role;

sub report_incoming {
    my ($self) = @_;
    
    my $table = Games::Lacuna::Task::Table->new(
        headline=> 'Incoming Ships Report',
        columns => ['Planet','Type','Ship','From','ETA'],
    );
    
    foreach my $planet_id ($self->my_planets) {
       $self->_report_incoming_planet($planet_id,$table);
    }
    
    return $table;
}

sub _report_incoming_planet {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    return
        unless defined($planet_stats->{incoming_foreign_ships});
    
    my %incoming;
    foreach my $element (@{$planet_stats->{incoming_foreign_ships}}) {
        my $type;
        if ($element->{is_own}) {
            $type = 'own';
        } elsif ($element->{is_ally}) {
            $type = 'ally';
        } else {
            $type = 'hostile';
        }
        $incoming{$element->{id}} = {
            type    => $type,
            from    => '?',
            ship    => '?',
            eta     => $self->parse_date($element->{date_arrives}),
        };
    }
    
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'SpacePort');
    
    if ($spaceport) {
        my $spaceport_object = $self->build_object($spaceport);
        
        # Get all incoming ships
        my $ships_data = $self->paged_request(
            object  => $spaceport_object,
            method  => 'view_foreign_ships',
            total   => 'number_of_ships',
            data    => 'ships',
        );
        
        my @incoming_ships;
        
        foreach my $element (@{$ships_data->{ships}}) {
            my $from = 'unknown';
            $incoming{$element->{id}}{ship} = $element->{type_human};
            if (defined $element->{from}) {
                $incoming{$element->{id}}{from} = ($element->{from}{empire}{name} // 'unknown').' '.($element->{from}{name} // 'unknown');
            }
        }
    }
    
    foreach my $element (values %incoming) {
        $table->add_row({
            planet  => $planet_stats->{name},
            %$element
        });
    }
}

no Moose::Role;
1;