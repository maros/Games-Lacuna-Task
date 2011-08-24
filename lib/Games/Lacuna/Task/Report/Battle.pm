package Games::Lacuna::Task::Report::Battle;

use 5.010;

use Moose::Role;

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
    
    my $timestamp = DateTime->now->set_time_zone('UTC')->subtract( hours => 24 );
    
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
        next
            if $battle->{attacking_unit} =~ m/excavator/i;
        my $date = $self->parse_date($battle->{date});
        next
            if $date < $timestamp;
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