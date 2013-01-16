package Games::Lacuna::Task::Action::StationPlanBuilder;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::Storage',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['space_station'] };

use Games::Lacuna::Task::Utils qw(parse_date format_date);
use List::Util qw(min max);

has 'space_station' => (
    isa         => 'Str',
    is          => 'ro',
    documentation=> q[Space station to be managed],
    predicate   => 'has_space_station',
);

has 'plans' => (
    is              => 'rw',
    isa             => 'HashRef',
    required        => 1,
    documentation   => 'Plans to be built [Required in config]',
    default         => sub {
        return {
            ArtMuseum           => { name => 'Art Museum', level => -3,  },
            CulinaryInstitute   => { name => 'Culinary Institute', level => -3 },
            IBS                 => { name => 'Interstellar Broadcast System', level => -3 },
            OperaHouse          => { name => 'Opera House', level => -3 },
            Parliament          => { skip => 1 },
            PoliceStation       => { name => 'Police Station', level => -3 },
            StationCommand      => { name => 'Station Command Center', skip => 1 },
            Warehouse           => { count => 5 },
        }
    },
);

sub description {
    return q[Build Space Station module plans];
}

sub run {
    my ($self) = @_;
    
    # Get plans on space station
    my ($space_station,$space_station_plans,$space_station_modules);
    if ($self->has_space_station) {
        $space_station = $self->space_station_data;
        $space_station_plans = $self->get_plans_stored($space_station->{id});
        $space_station_modules = $self->get_modules_built($space_station->{id});
    }
    
    # Get plans on bodies
    my (@planet_plans);
    foreach my $planet_stats ($self->get_planets) {
        $self->log('info',"Check planet %s",$planet_stats->{name});
        push(@planet_plans,$self->check_planet($planet_stats));
    }
    
    # Get total plans
    my $total_plans = _merge_plan_hash(@planet_plans,$space_station_plans,$space_station_modules);
    
    # Build plans
    foreach my $planet_stats ($self->get_planets) {
        $self->log('info',"Process planet %s",$planet_stats->{name});
        $self->process_planet($planet_stats,$total_plans);
    }
}

sub check_planet {
    my ($self,$planet_stats) = @_;
    
    my $timestamp = time();
    
    # Get space station lab
    my $spacestaion_lab = $self->find_building($planet_stats->{id},'SSLA');
    
    return
        unless $spacestaion_lab;

    # Get plans on planet
    my $planet_plans = $self->get_plans_stored($planet_stats->{id});

    # Get working plans
    if (defined $spacestaion_lab->{work}) {
        my $spacestaion_lab_object = $self->build_object($spacestaion_lab);
        my $spacestaion_lab_data = $self->request(
            object  => $spacestaion_lab_object,
            method  => 'view',
        );
        
        if (defined $spacestaion_lab_data->{building}{work}
            && $spacestaion_lab_data->{make_plan}{making} =~ m/^(.+)\s\((\d+)\+0\)$/) {
            my $plan_name = $1;
            my $plan_level = $2;
            my $plan_ident;
            foreach (keys %{$self->plans}) {
                my $plan_check_name = $self->plans->{$_}{name} || $_;
                if ($plan_name eq $plan_check_name) {
                    $plan_ident = $_;
                    last;   
                }  
            }
            $planet_plans->{$plan_ident} ||= {};
            $planet_plans->{$plan_ident}{$plan_level} ||= 0;
            $planet_plans->{$plan_ident}{$plan_level}++;
        }
    }
    
    # TODO: Get plans in transit
    
    return ($planet_plans);
}

sub process_planet {
    my ($self,$planet_stats,$total_plans) = @_;

    # Get space station lab
    my $spacestaion_lab = $self->find_building($planet_stats->{id},'SSLA');
    
    return
        unless $spacestaion_lab;

    my $timestamp = time();

    if (defined $spacestaion_lab->{work}) {
        my $work_end = parse_date($spacestaion_lab->{work}{end});
        if ($work_end > $timestamp) {
            $self->log('debug','Space station lab is busy until %s',format_date($work_end));
            return;
        }
    }

    # Get max level
    my $max_level = max(map { keys %{$_} } values %{$total_plans});
    $max_level = min($spacestaion_lab->{level},$max_level+1);
    
    my $spacestaion_lab_object = $self->build_object($spacestaion_lab);
    my $spacestaion_lab_data = $self->request(
        object  => $spacestaion_lab_object,
        method  => 'view',
    );
    
    PLAN_LEVEL:
    foreach my $level (1..$max_level) {
         last PLAN_LEVEL
            unless $self->can_afford($planet_stats,$spacestaion_lab_data->{make_plan}{level_costs}[$level-1]);
        
        PLAN_TYPE:
        foreach my $plan (keys %{$self->plans}) {
            my $plan_data = $self->plans->{$plan};
            my $plan_level = $plan_data->{level} || $max_level;
            my $plan_name = $plan_data->{name} || $plan;
            my $plan_skip = $plan_data->{skip} || 0;
            my $count = $plan_data->{count} // 1;
            
            $count += $max_level
                if $count > 1;
            
            $plan_level = $max_level + $plan_level
                if ($plan_level < 0);
           
            next PLAN_TYPE
                if $level <= $plan_skip;
            next PLAN_TYPE
                if $level > $plan_level;
            
            $total_plans->{$plan}{$level} //= 0;
            if ($total_plans->{$plan}{$level} < $count) {
                $self->log('notice','Building plan %s (%i) on %s',$plan_name,$level,$planet_stats->{name});
                my ($plan_type) = map { $_->{type} } grep { $_->{name} eq $plan_name } @{$spacestaion_lab_data->{make_plan}{types}};
                
                my $response = $self->request(
                    object  => $spacestaion_lab_object,
                    method  => 'make_plan',
                    params  => [$plan_type,$level],
                    catch       => [
                        [
                            1011,
                            sub {
                                my ($error) = @_;
                                $self->log('debug',"Could not build module %s (%i): %s",$plan_type,$level,$error->message);
                                return 0;
                            }
                        ]
                    ],
                );
                
                if (defined $response) {
                    $total_plans->{$plan}{$level}++;
                }
                            
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
        my $quantity = $plan->{quantity};
        
        next
            unless $plan->{extra_build_level} == 0;
        next
            unless defined $space_station_plans{$name};
        
        my $plan_key = $space_station_plans{$name};
        $stored_plans{$plan_key} ||= {};
        $stored_plans{$plan_key}->{$level} = $quantity;
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
        
        # Add building level 
        if ($module->{pending_build}) {
            my $level = $module->{level};
            $level ++;
            $modules_built{$type}->{$level} ||= 0;
            $modules_built{$type}->{$level} ++;
        }
        
        # Add levels
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

=pod

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::StationPlanBuilder - Build Space Station module plans

=head1 DESCRIPTION

This task automates the building of space station modules.

=cut