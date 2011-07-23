package Games::Lacuna::Task::Automator::Intelligence;

use 5.010;

use List::Util qw(min);

use Moose;
extends qw(Games::Lacuna::Task::Automator);

has 'offensive_assignment' => (
    isa             => 'ArrayRef',
    is              => 'rw',
    required        => 1,
    default         => sub { ['Gather Resource Intelligence','Gather Empire Intelligence','Gather Operative Intelligence'] },
    documentation   => 'Default offensive spy assignment',
);

has 'max_missions' => (
    isa             => 'Int',
    is              => 'rw',
    required        => 1,
    default         => 25,
    documentation   => 'Max offensive missions per spy',
);

sub description {
    return q[This task automates the assignment of spies];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Get intelligence ministry
    my ($intelligence_ministry) = $self->find_building($planet_stats->{id},'Intelligence');
    return
        unless $intelligence_ministry;
    my $intelligence_ministry_object = $self->build_object($intelligence_ministry);
    
    # Get security ministry
    my ($security_ministry) = $self->find_building($planet_stats->{id},'Security');
    my @foreign_spies_active;
    my $foreign_spies_count = 0;
    if ($security_ministry) {
        
        my $security_ministry_object = $self->build_object($security_ministry);
        my $foreign_spy_data = $self->request(
            object  => $security_ministry_object,
            method  => 'view_foreign_spies',
            params  => [ { no_paging => 1 } ],
        );
        
        $foreign_spies_count = $foreign_spy_data->{spy_count};
        
        # Check if we have active foreign spies (not idle) that can be discovered via security sweep
        if ($foreign_spy_data->{spy_count} > 0) {
            $self->log('warn',"There are %i foreign spies on %s",$foreign_spy_data->{spy_count},$planet_stats->{name});
            foreach my $spy (@{$foreign_spy_data->{spies}}) {
                my $next_mission = $self->parse_date($spy->{next_mission});
                if ($next_mission > $timestamp) {
                    push(@foreign_spies_active,$spy->{level})
                }
            }
        }
    }
    
    my $spy_data = $self->request(
        object  => $intelligence_ministry_object,
        method  => 'view_spies',
        params  => [ { no_paging => 1 } ],
    );
    
    # Loop all spies
    my $counter = 1;
    my $defensive_spy_count = 0;
    my %defensive_spy_assignments;
    foreach my $spy (@{$spy_data->{spies}}) {
        
        # Spy is on this planet
        if ($spy->{assigned_to}{body_id} == $planet_stats->{id}) {
            $defensive_spy_assignments{$spy->{assignment}} ||= [];
            push(@{$defensive_spy_assignments{$spy->{assignment}}},$spy);
            $defensive_spy_count ++;
        # Spy is on another planet
        } else {
            next
                unless $spy->{is_available};
            next
                unless $spy->{assignment} eq 'Idle';
            my $assignment;
            # My planet
            if ($spy->{assigned_to}{body_id} ~~ [ $self->planet_ids ]) {
                $assignment = 'Counter Espionage';
            # Foreign planet
            } else {
                next 
                    if $spy->{mission_count}{offensive} > $self->max_missions;
                # TODO Check if empire is ally
                # TODO Some way to configure offensive assignment
                my $assignment_index = rand(scalar @{$self->offensive_assignment});
                $assignment = $self->offensive_assignment->[$assignment_index];
            }
            $self->log('notice',"Assigning spy %s from %s on %s to %s",$spy->{name},$planet_stats->{name},$spy->{assigned_to}{name},$assignment);
            my $response = $self->request(
                object  => $intelligence_ministry_object,
                method  => 'assign_spy',
                params  => [$spy->{id},$assignment],
            );
            unless ($response->{mission}{result} eq 'Success') {
                $self->log('warn',"Mission of spy %s from %s on %s failed: %s",$spy->{name},$planet_stats->{name},$spy->{assigned_to}{name},$response->{mission}{reason});
            }
        }
        $counter ++;
    }
    
    # Assign local spies
    foreach my $spy (@{$spy_data->{spies}}) {
        next
            unless $spy->{is_available};
        next
            unless $spy->{assigned_to}{body_id} == $planet_stats->{id};
        
        my $assignment;
        
        # Run security sweep
        if (scalar @foreign_spies_active
            && ! defined $defensive_spy_assignments{'Security Sweep'}
            && min(@foreign_spies_active)-1 <= $spy->{level} 
            && $defensive_spy_count > $foreign_spies_count
            && $spy->{mission_count}{defensive} <= $self->max_missions) {
            $assignment = 'Security Sweep';
        # Assign to counter espionage
        } elsif ($spy->{assignment} eq 'Idle') {
            $assignment = 'Counter Espionage';
        }
        
        # Set new assignment
        if ($assignment) {
            $defensive_spy_assignments{$assignment} ||= [];
            push(@{$defensive_spy_assignments{$assignment}},$spy);
            $self->log('notice',"Assigning spy %s on %s to %s",$spy->{name},$planet_stats->{name},$assignment);
            $self->request(
                object  => $intelligence_ministry_object,
                method  => 'assign_spy',
                params  => [$spy->{id},$assignment],
            );
        }
    }
    
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;