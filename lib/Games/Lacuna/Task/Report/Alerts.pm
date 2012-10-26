package Games::Lacuna::Task::Report::Alerts;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;
use Games::Lacuna::Task::Utils qw(parse_date);

use Moose::Role;
with qw(Games::Lacuna::Task::Role::Building);

sub report_alerts {
    my ($self) = @_;
    
    my $table = Games::Lacuna::Task::Table->new(
        headline=> 'Alerts',
        columns => ['Planet','Alert'],
    );
    
    foreach my $planet_id ($self->my_planets) {
        $self->_report_alert_resources($planet_id,$table);
        $self->_report_alert_happiness($planet_id,$table);
        $self->_report_alert_damage($planet_id,$table);
        $self->_report_alert_waste($planet_id,$table);
        $self->_report_alert_build_queue($planet_id,$table);
        $self->_report_alert_buildings($planet_id,$table);
    }
    
    return $table;
}

sub _report_alert_happiness {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    if ($planet_stats->{happiness} < 0) {
        $table->add_row({
            planet          => $planet_stats->{name},
            alert           => "Negative happiness",
        });
    }
    
    if ($planet_stats->{happiness_hour} < 0) {
        $table->add_row({
            planet          => $planet_stats->{name},
            alert           => "Negative happiness flow",
        });
    }
}

sub _report_alert_damage {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    foreach my $building_data ($self->buildings_body($planet_id)) {
        next
            if $building_data->{efficiency} == 100;
        
        my $building_object = $self->build_object($building_data);
        my $building_detail = $self->request(
            object  => $building_object,
            method  => 'view',
        );
        
        $building_data = $building_detail->{building};
        
        # Check if building really needs repair
        next
            if $building_data->{efficiency} == 100;
            
        $table->add_row({
            planet          => $planet_stats->{name},
            alert           => sprintf(
                'Building %s(%i) damaged (%i%%)',
                $building_data->{name},
                $building_data->{level},
                $building_data->{efficiency},
            ),
        });
    }
}

sub _report_alert_resources {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    foreach my $ressource (@Games::Lacuna::Task::Constants::RESOURCES) {
        my $stored = $planet_stats->{$ressource.'_stored'};
        my $capacity = $planet_stats->{$ressource.'_capacity'};
        my $production  = $planet_stats->{$ressource.'_hour'};

        if ($stored <= $capacity * 0.1) {
            $table->add_row({
                planet          => $planet_stats->{name},
                alert           => sprintf(
                    '%s running low',
                    $ressource,
                ),
            });
        }

        if ($production <= 0) {
            $table->add_row({
                planet          => $planet_stats->{name},
                alert           => sprintf(
                    'Negative %s production',
                    $ressource,
                ),
            });
        }
    }
}

sub _report_alert_waste {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    my $stored = $planet_stats->{'waste_stored'};
    my $capacity = $planet_stats->{'waste_capacity'};
    my $production  = $planet_stats->{'waste_hour'};
    
    if ($stored > $capacity * 0.9) {
        $table->add_row({
            planet          => $planet_stats->{name},
            alert           => 'Overflowing waste',
        });
    }
    
    if ($stored < $capacity * 0.05) {
        $table->add_row({
            planet          => $planet_stats->{name},
            alert           => 'Not enough waste',
        });
    }
}

sub _report_alert_build_queue {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    my $build_queue_size = $self->build_queue_size($planet_id);
    
    if ($build_queue_size == 0) {
        $table->add_row({
            planet          => $planet_stats->{name},
            alert           => 'Empty build queue',
        });
    }
}

sub _report_alert_buildings {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    
    foreach my $building_data ($self->buildings_body($planet_id)) {
        next
            unless $building_data->{url} eq '/deployedbleeder'
            || $building_data->{url} eq '/fissure';
            
        $table->add_row({
            planet          => $planet_stats->{name},
            alert           => sprintf(
                '%s level %i',
                $building_data->{name},
                $building_data->{level},
            ),
        });
    }
}

no Moose::Role;
1;