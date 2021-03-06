package Games::Lacuna::Task::Report::Incoming;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;

use Games::Lacuna::Task::Utils qw(format_date parse_date);

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
    
    # Get space port
    my $spaceport = $self->find_building($planet_stats->{id},'SpacePort');
    
    return 
        unless defined $spaceport;
    
    my $spaceport_object = $self->build_object($spaceport);
    
    # Get all incoming ships
    my $ships_data = $self->paged_request(
        object  => $spaceport_object,
        method  => 'view_foreign_ships',
        total   => 'number_of_ships',
        data    => 'ships',
    );
    
    my %incoming;
    
    foreach my $element (@{$ships_data->{ships}}) {
        my $type;
        
        unless (defined $element->{from} 
            && defined $element->{from}{empire}) {
            $type = 'hostile';
        } elsif ($element->{from}{empire}{id} == $planet_stats->{empire}{id}) {
            $type = 'own';
        # Check for ally
        #} elsif ($from->{empire}{id} == $ally) {
        #   $type = 'ally';
        } else {
            $type = 'hostile';
        }
        
        my $from = 'unknown';
        $incoming{$element->{id}} = {
            type    => $type,
            from    => $from,
            ship    => $element->{type_human},
            eta     => format_date(parse_date($element->{date_arrives})),
        };
        if (defined $element->{from}) {
            $incoming{$element->{id}}{from} = ($element->{from}{empire}{name} // 'unknown').' '.($element->{from}{name} // 'unknown');
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