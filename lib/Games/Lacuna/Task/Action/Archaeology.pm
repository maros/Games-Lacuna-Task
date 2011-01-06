package Games::Lacuna::Task::Action::Archaeology;

use 5.010;

use Moose;
use List::Util qw(max sum);

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger);

sub all_glyphs {
    my ($self) = @_;
    
    my $all_gylphs = $self->lookup_cache('glyphs');
    
    return $all_gylphs
        if defined $all_gylphs;
    
    # Fetch total glyph count from cache/server
    $all_gylphs = { map { $_ => 0 } @Games::Lacuna::Task::Constants::ORES };
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        # Get archaeology ministry
        my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology Ministry');
        
        next
            unless defined $archaeology_ministry;
        
        # Get all glyphs
        my $archaeology_ministry_object = Games::Lacuna::Client::Buildings::Archaeology->new(
            client      => $self->client->client,
            id          => $archaeology_ministry->{id},
        );
        my $gylph_data = $self->request(
            object  => $archaeology_ministry_object,
            method  => 'get_glyphs',
        );
        
        foreach my $glyph (@{$gylph_data->{glyphs}}) {
            $all_gylphs->{$glyph->{type}} ||= 0;
            $all_gylphs->{$glyph->{type}} ++;
        }
    }
    
    $self->write_cache(
        key     => 'glyphs',
        value   => $all_gylphs,
        max_age => (60*60*24),
    );
    
    return $all_gylphs;
}

sub run {
    my ($self) = @_;
    
    my $all_gylphs = $self->all_glyphs;
    my $total_glyphs = sum(values %{$all_gylphs});
    my $max_glyphs = max(values %{$all_gylphs});
    
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Loop all planets again
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        $self->log('info',"Processing planet %s",$planet_stats->{name});
        
        # Get archaeology ministry
        my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology Ministry');
        
        next
            unless defined $archaeology_ministry;
        
        # Check archaeology is busy
        if (defined $archaeology_ministry->{work}) {
            my $work_end = $self->parse_date($archaeology_ministry->{work}{end});
            if ($work_end > $timestamp) {
                next;
            }
        }
        
        # Get local ores
        my %ores;
        foreach my $ore (keys %{$planet_stats->{ore}}) {
            $ores{$ore} = 1
                if $planet_stats->{ore}{$ore} > 1;
        }
        
        # Get local ores form mining platforms
        my $mining_ministry = $self->find_building($planet_stats->{id},'Mining Ministry');
        if (defined $mining_ministry) {
            my $mining_ministry_object = Games::Lacuna::Client::Buildings::MiningMinistry->new(
                client      => $self->client->client,
                id          => $mining_ministry->{id},
            );
            
            my $platforms = $self->request(
                object  => $mining_ministry_object,
                method  => 'view_platforms',
            );
            
            if (defined $platforms
                && $platforms->{platforms}) {
                foreach my $platform (@{$platforms->{platforms}}) {
                    foreach my $ore (keys %{$platform->{asteroid}{ore}}) {
                        $ores{$ore} = 1
                            if $platform->{asteroid}{ore}{$ore} > 1;
                    }
                }
            }
        }
        
        my $archaeology_ministry_object = Games::Lacuna::Client::Buildings::Archaeology->new(
            client      => $self->client->client,
            id          => $archaeology_ministry->{id},
        );
        
        # Get searchable ores
        my $archaeology_ores = $self->request(
            object  => $archaeology_ministry_object,
            method  => 'get_ores_available_for_processing',
        );
        
        foreach my $ore (keys %ores) {
            if (defined $archaeology_ores->{ore}{$ore}) {
                $ores{$ore} = $archaeology_ores->{ore}{$ore};
            } else {
                delete $ores{$ore}
            }
        }
        
        # Check best suited glyph
        for my $max_glyph (0..$max_glyphs) {
            foreach my $ore (keys %ores) {
                next
                    if $all_gylphs->{$ore} > $max_glyph;
                $self->log('notice',"Searching for %s glyph on %s",$ore,$planet_stats->{name});
                $self->request(
                    object  => $archaeology_ministry_object,
                    method  => 'search_for_glyph',
                    params  => [$ore],
                );
                
                $self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
                
                next PLANETS;
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;