package Games::Lacuna::Task::Action::Intelligence;

use 5.010;

use Moose;
use List::Util qw(min);

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

has 'offensive_assignment' => (
    isa             => 'Str',
    is              => 'rw',
    required        => 1,
    default         => 'Gather Resource Intelligence',
    documentation   => 'Default offensive spy assignment',
);

sub run {
    my ($self) = @_;
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        
        # Get ministries
        my ($intelligence_ministry) = $self->find_building($planet_stats->{id},'Intelligence Ministry');
        my ($security_ministry) = $self->find_building($planet_stats->{id},'Security Ministry');
        
        my $intelligence_ministry_object = Games::Lacuna::Client::Buildings::Intelligence->new(
            client      => $self->client->client,
            id          => $intelligence_ministry->{id},
        );
        
        my $ministry_data = $self->request(
            object  => $intelligence_ministry_object,
            method  => 'view',
        );
        
        # Check if we can have more spies
        my $spy_slots = $ministry_data->{spies}{maximum} > ($ministry_data->{spies}{current} + $ministry_data->{spies}{in_training});
        
        if ($spy_slots > 0
            && $self->can_afford($planet_stats,$ministry_data->{spies}{training_costs})) {
            $self->log('notice',"Training spy on %s",$planet_stats->{name});
            $self->request(
                object  => $intelligence_ministry_object,
                method  => 'train_spy',
                params  => [1]
            );
        }
        
        # Check if we have idle foreign spies
        my $foreign_idle_spies = 0;
        if ($security_ministry) {
            my $security_ministry_object = Games::Lacuna::Client::Buildings::Security->new(
                client      => $self->client->client,
                id          => $security_ministry->{id},
            );
            my $foreign_spy_data = $self->paged_request(
                object  => $security_ministry_object,
                method  => 'view_foreign_spies',
                total   => 'spy_count',
                data    => 'spies',
            );
            
            if ($foreign_spy_data->{spy_count} > 0) {
                $self->log('warn',"There are %i foreign spies on %s",$foreign_spy_data->{spy_count},$planet_stats->{name});
                
                foreach my $spy (@{$foreign_spy_data->{spies}}) {
                    $foreign_idle_spies ++
                        if $spy->{next_mission} ne $foreign_spy_data->{status}{server}{time};
                }
            }
        }
        
        
        # Get intelligence ministry
        my $security_ministry_object = Games::Lacuna::Client::Buildings::Intelligence->new(
            client      => $self->client->client,
            id          => $intelligence_ministry->{id},
        );
        
        my $spy_data = $self->paged_request(
            object  => $intelligence_ministry_object,
            method  => 'view_spies',
            total   => 'spy_count',
            data    => 'spies',
        );
        
        # Loop all spies
        my $counter = 1;
        my $defensive_counter = 0;
        foreach my $spy (@{$spy_data->{spies}}) {
            if (lc($spy->{name}) eq 'agent null') {
                $spy->{name} = sprintf('Agent %02i %s',$counter,$planet_stats->{name});
                $self->log('notice',"Renaming spy %s on %s",$spy->{name},$planet_stats->{name});
                $self->request(
                    object  => $intelligence_ministry_object,
                    method  => 'name_spy',
                    params  => [$spy->{id},$spy->{name}]
                );
            }
            
            if (! $spy->{is_available} ) {
                if ($spy->{assigned_to}{body_id} == $planet_stats->{id}
                    && $spy->{assignment} eq 'Security Sweep') {
                    $defensive_counter ++;
                }
                next;
            }
            
            my $assignment;
            
            # Spy is on this planet
            if ($spy->{assigned_to}{body_id} == $planet_stats->{id}) {
                $defensive_counter ++;
                if ($spy->{assignment} ~~ ['Idle','Counter Espionage']
                    && $foreign_idle_spies >= $defensive_counter) {
                    $assignment = 'Security Sweep';
                }
            # Spy is on another planet in my empire
            } elsif ($spy->{assigned_to}{body_id} ~~ [ $self->planet_ids ]) {
                $assignment = 'Counter Espionage'
                    if $spy->{assignment} eq 'Idle';
            # Spy is on a foreign planet
            } else {
                $assignment = $self->offensive_assignment
                    if $spy->{assignment} eq 'Idle';
            }
            
            if ($assignment) {
                $self->log('notice',"Assigning spy %s from %s on %s to %s",$spy->{name},$planet_stats->{name},$spy->{assigned_to}{name},$assignment);
                $self->request(
                    object  => $intelligence_ministry_object,
                    method  => 'assign_spy',
                    params  => [$spy->{id},$assignment],
                );
            }
            
            $counter ++;
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;