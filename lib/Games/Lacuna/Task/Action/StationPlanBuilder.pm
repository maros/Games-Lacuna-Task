package Games::Lacuna::Task::Action::StationPlanBuilder;

use 5.010;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Storage',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['home_planet'] };

has 'space_station' => (
    isa         => 'Str',
    is          => 'ro',
    predicate   => 'has_space_station',
    documentation=> q[Space station to be managed],
);

has 'plans' => (
    is              => 'rw',
    isa             => 'HashRef',
    required        => 1,
    documentation   => 'plans to be built',
    default         => sub {
        return {
            ArtMuseum           => { name => 'Art Museum', level => -3 },
            CulinaryInstitute   => { name => 'Culinary Institute', level => -3 },
            IBS                 => { name => 'Interstellar Broadcast System', level => -3 },
            OperaHouse          => { name => 'Opera House', level => -3 },
            Parliament          => { },
            PoliceStation       => { name => 'Police Station', level => -3 },
            StationCommand      => { name => 'Station Command Center' },
            Warehouse           => { count => 13, level => 18 },
        }
    },
);

sub description {
    return q[Build Space Station module plans];
}

sub run {
    my ($self) = @_;
    
    my $planet_home = $self->home_planet_data();
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Get space station lab
    my $spacestaion_lab = $self->find_building($planet_home->{id},'SSLA');
    return $self->log('error','Could not find space station labs')
        unless $spacestaion_lab;

    if (defined $spacestaion_lab->{work}) {
        my $work_end = $self->parse_date($spacestaion_lab->{work}{end});
        if ($work_end > $timestamp) {
            return $self->log('info','Space station lab is busy until %s %s',$work_end->ymd('.'),$work_end->hms(':'))
        }
    }

    my $spacestaion_lab_object = $self->build_object($spacestaion_lab);
    
    # Get plans on planet
    my $planet_plans = $self->get_plans_stored($planet_home->{id});
    
    # Get plans on space station
    my ($space_station,$space_station_plans,$space_station_modules);
    if ($self->has_space_station) {
        $space_station = $self->my_body_status($self->space_station);
        return $self->log('error','Could not find space station')
            unless (defined $space_station);
        $space_station_plans = $self->get_plans_stored($space_station->{id});
        $space_station_modules = $self->get_modules_built($space_station->{id});
    }
    
    # TODO: Get plans in transit
    
    # Get total plans
    my $total_plans = _merge_plan_hash($planet_plans,$space_station_plans,$space_station_modules);
    
    # Get max level
    my $max_level = $spacestaion_lab->{level};
    
    PLAN_LEVEL:
    foreach my $level (1..$max_level) {
        PLAN_TYPE:
        foreach my $plan (keys %{$self->plans}) {
            my $plan_level = $self->plans->{$plan}{level} || $max_level;
            my $plan_name = $self->plans->{$plan}{name} || $plan;
            my $count = $self->plans->{$plan}{count} // 1;
            $plan_level = $max_level + $plan_level
                if ($plan_level < 0);
            
            next
                if $plan_level <= 0;
            
            $total_plans->{$plan}{$level} //= 0;
            if ($total_plans->{$plan}{$level} < $count) {
                $self->log('notice','Building plan %s (%i) on %s',$plan_name,$level,$planet_home->{name});
                my $response = $self->request(
                    object  => $spacestaion_lab_object,
                    method  => 'make_plan',
                    params  => [lc($plan),$level],
                );
                #$response->{building}{work}{end};
                return;
            }
        }
    }
}

sub _merge_plan_hash {
    my (@args) = @_;
    
    my $return = {};
    
    foreach my $hash (@args) {
        next
            unless defined $hash;
        while (my ($plan,$levels) = each %{$hash}) {
            $return->{$plan} ||= {};
            while (my ($level,$count) = each %{$levels}) {
                $return->{$plan}{$level} ||= 0;
                $return->{$plan}{$level} += $count;
            }
        }
    }
    
    return $return;
}

sub get_plans_stored {
    my ($self,$body_id) = @_;
    
    my $plans = $self->plans_stored($body_id);
    
    my %space_station_plans;
    while (my ($plan,$data) = each %{$self->plans}) {
        $space_station_plans{$data->{name} || $plan} = $plan;
    }
    
    my %stored_plans;
    foreach my $plan (@{$plans}) {
        my $name = $plan->{name};
        my $level = $plan->{level};
        
        next
            unless $plan->{extra_build_level} == 0;
        next
            unless defined $space_station_plans{$name};
        
        my $plan_key = $space_station_plans{$name};
        $stored_plans{$plan_key} ||= {};
        $stored_plans{$plan_key}->{$level} ||= 0;
        $stored_plans{$plan_key}->{$level} ++;
    }
    
    return \%stored_plans;
}

sub get_modules_built {
    my ($self,$body_id) = @_;
    
    my %modules_built;
    
    foreach my $module ($self->buildings_body($body_id)) {
        my $type = Games::Lacuna::Client::Buildings::type_from_url($module->{url});
        next
            unless defined $self->plans->{$type};
        foreach my $level (1..$module->{level}) {
            $modules_built{$type} ||= {};
            $modules_built{$type}->{$level} ||= 0;
            $modules_built{$type}->{$level} ++;
        }
    }
    
    return \%modules_built;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;