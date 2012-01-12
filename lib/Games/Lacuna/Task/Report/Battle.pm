package Games::Lacuna::Task::Report::Battle;

use 5.010;

use Moose::Role;

use Games::Lacuna::Task::Utils qw(parse_date);

sub report_battle {
    my ($self) = @_;
    
    my $table = Games::Lacuna::Task::Table->new(
        headline=> 'Battle Report',
        columns => ['Planet','System','Attacker','Attacking Ship','Defending Ship','Victory'],
    );
    
    foreach my $planet_id ($self->my_planets) {
        return $table
            if $self->_report_battle_body($planet_id,$table);
    }
    
    return $table;
}

sub _report_battle_body {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    my $limit = time() - (60 * 60 * 24); # 24 hours
    
    # Get mining ministry
    my ($spaceport) = $self->find_building($planet_stats->{id},'SpacePort');
    
    return
        unless $spaceport;
    
    my $spaceport_object = $self->build_object($spaceport);
    
    my $battle_data = $self->paged_request(
        object  => $spaceport_object,
        method  => 'view_battle_logs',
        total   => 'number_of_logs',
        data    => 'battle_log',
    );
    
    foreach my $battle (@{$battle_data->{battle_log}}) {
        my $date = parse_date($battle->{date});
        next
            if $date < $limit;
        $table->add_row({
            planet          => $planet_stats->{name},
            system          => $battle->{defending_body},
            attacker        => $battle->{attacking_empire},
            attacking_ship  => $battle->{attacking_unit},
            defending_ship  => $battle->{defending_unit},
            victory         => $battle->{victory_to},
        });
    }
    
    return 1;
}

no Moose::Role;
1;