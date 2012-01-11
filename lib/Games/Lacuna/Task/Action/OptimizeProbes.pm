package Games::Lacuna::Task::Action::OptimizeProbes;

use 5.010;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::PlanetRun
    Games::Lacuna::Task::Role::Stars);

sub description {
    return q[Checks for duplicate probes];
}

has '_probe_cache' => (
    is              => 'rw',
    isa             => 'HashRef',
    required        => 1,
    default         => sub { {} },
    traits          => ['Hash','NoGetopt'],
    handles         => {
        add_probe_cache     => 'set',
        has_probe_cache     => 'exists',
    }
);

sub process_planet {
    my ($self,$planet_stats) = @_;
        
    # Get observatory
    my $observatory = $self->find_building($planet_stats->{id},'Observatory');
    
    return 
        unless $observatory;
    
    # Get observatory probed stars
    my $observatory_object = $self->build_object($observatory);
    my $observatory_data = $self->paged_request(
        object  => $observatory_object,
        method  => 'get_probed_stars',
        total   => 'star_count',
        data    => 'stars',
    );
    
    # Loop all stars
    foreach my $star_data (@{$observatory_data->{stars}}) {
        # Update cache
        $star_data->{last_checked}  = time();
        $star_data->{probed}        = 1;
        $self->set_star_cache($star_data);
        
        my $star_id = $star_data->{id};
        if ($self->has_probe_cache($star_id)) {
            $self->log('notice',"Abandoning probe from %s in %s",$planet_stats->{name},$star_data->{name});
            $self->request(
                object  => $observatory_object,
                method  => 'abandon_probe',
                params  => [$star_id],
            );
            
            # Check star status
            $self->_get_star_api($star_data->{id},$star_data->{x},$star_data->{y});
        } else {
            $self->add_probe_cache($star_id,1);
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;