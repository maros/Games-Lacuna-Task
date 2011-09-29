package Games::Lacuna::Task::Action::Mission;

use 5.010;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun
    Games::Lacuna::Task::Role::Storage);

use Games::Lacuna::Client::Types qw(ore_types food_types);
use YAML::Any qw(LoadFile);

sub description {
    return q[Automatically accept missions];
}

has 'missions' => (
    is              => 'rw',
    isa             => 'ArrayRef[Str]',
    required        => 1,
    documentation   => 'Automatic missions',
);

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Get mission command
    my ($missioncommand) = $self->find_building($planet_stats->{id},'MissionCommand');
    return
        unless $missioncommand;
    my $missioncommand_object = $self->build_object($missioncommand);
    
    my $mission_data = $self->request(
        object  => $missioncommand_object,
        method  => 'get_missions',
    );
    
    my $plans;
    my $glyphs;
    
    MISSIONS:
    foreach my $mission (@{$mission_data->{missions}}) {
        next
            unless lc($mission->{name}) ~~ lc($self->missions);
        
        my @used_plans;
        foreach my $objective (@{$mission->{objectives}}) {
            given ($objective) {
                when (m/^
                    (?<name>[^(]+)
                    \s
                    \(
                        >=
                        \s
                        (?<level>\d+)
                        (\+(?<extra_build_level>\d+))?
                    \)
                    \s
                    plan$/x) {
                    $plans ||= $self->plans_stored($planet_stats->{id});
                    
                    my $found_plan = 0;
                    PLANS:
                    foreach my $plan (@$plans) {
                        
                        next PLANS
                            unless $plan->{name} eq $+{name};
                        next PLANS
                            if $plan->{level} != $+{level};
                        next PLANS
                            if $plan->{extra_build_level} != ($+{extra_build_level} // 0);
                        next PLANS
                            if grep { $plan == $_ } @used_plans;
                        push (@used_plans,$plan);
                        $found_plan ++;
                    }
                    next MISSIONS
                        unless $found_plan;
                }
                when (m/^(?<quantity>[,0-9]+)\s(?<resource>.+)$/) {
                    my $quantity = $+{quantity};
                    my $resource = $+{resource};
                    $quantity =~ s/\D//g;
                    $quantity += 0;
                    next MISSIONS
                        if $quantity > $self->check_stored($planet_stats,$resource);
                }
                when (m/^(?<resource>.+)\sglyph$/) {
                    # no check
                }
                default {
                    # not implemented
                    next MISSIONS;
                }
#                when (m/^
#                    (?<ship>[^(]+)
#                    \s
#                    \(
#                        speed \s >= (?<speed>\d+),
#                        \s
#                        stealth \s >= (?<stealth>\d+),
#                        \s
#                        hold \s size \s >= (?<hold>\d+),
#                        \s
#                        combat \s >= (?<combat>\d+),
#                    \)
#                    $/x) {
#                    # TODO check ship
#                }
            }
        }
        
        # TODO check if we can store rewards
        
        $self->log('notice',"Completing mission %s on %s",$mission->{name},$planet_stats->{name});
        
        try {
            $self->request(
                object  => $missioncommand_object,
                method  => 'complete_mission',
                params  => [$mission->{id}],
            );
        } catch {
            my $error = $_;
            if (blessed($error)
                && $error->isa('LacunaRPCException')) {
                if ($error->code == 1013) {
                    $self->log('debug',"Could not complete mission %s: %s",$mission->{name},$error->message);
                } else {
                    $error->rethrow();
                }    
            } else {
                die($error);
            }
        };
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;