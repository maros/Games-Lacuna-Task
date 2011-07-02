package Games::Lacuna::Task::Action::Archaeology;

use 5.010;

use List::Util qw(max sum);

use Moose;
extends qw(Games::Lacuna::Task::Action);

sub description {
    return q[This task automates the search for glyphs];
}

sub all_glyphs {
    my ($self) = @_;
    
    # Fetch total glyph count from cache
    my $all_gylphs = $self->lookup_cache('glyphs');
    
    return $all_gylphs
        if defined $all_gylphs;
    
    # Set all glyphs to zero
    {
        no warnings 'once';
        $all_gylphs = { map { $_ => 0 } @Games::Lacuna::Task::Constants::ORES };
    }
    
    # Loop all planets
    PLANETS:
    foreach my $planet_stats ($self->planets) {
        # Get archaeology ministry
        my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
        
        next
            unless defined $archaeology_ministry;
        
        # Get all glyphs
        my $archaeology_ministry_object = $self->build_object($archaeology_ministry);
        my $gylph_data = $self->request(
            object  => $archaeology_ministry_object,
            method  => 'get_glyphs',
        );
        
        foreach my $glyph (@{$gylph_data->{glyphs}}) {
            $all_gylphs->{$glyph->{type}} ||= 0;
            $all_gylphs->{$glyph->{type}} ++;
        }
    }
    
    # Write total glyph count to cache
    $self->write_cache(
        key     => 'glyphs',
        value   => $all_gylphs,
        max_age => (60*60*24),
    );
    
    return $all_gylphs;
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    my $all_gylphs = $self->all_glyphs;
    my $total_glyphs = sum(values %{$all_gylphs});
    my $max_glyphs = max(values %{$all_gylphs});
    my $timestamp = DateTime->now->set_time_zone('UTC');
    
    # Get archaeology ministry
    my $archaeology_ministry = $self->find_building($planet_stats->{id},'Archaeology');
    
    return
        unless defined $archaeology_ministry;
    
    # Check archaeology is busy
    if (defined $archaeology_ministry->{work}) {
        my $work_end = $self->parse_date($archaeology_ministry->{work}{end});
        if ($work_end > $timestamp) {
            return;
        }
    }
    
    my $archaeology_ministry_object = $self->build_object($archaeology_ministry);
    
    # Get searchable ores
    my $archaeology_view = $self->request(
        object  => $archaeology_ministry_object,
        method  => 'view',
    );
    
    return
        if defined $archaeology_view->{building}{work}{seconds_remaining};
    
    # Get local ores
    my %ores;
    foreach my $ore (keys %{$planet_stats->{ore}}) {
        $ores{$ore} = 1
            if $planet_stats->{ore}{$ore} > 1;
    }
    
    # Get local ores form mining platforms
    my $mining_ministry = $self->find_building($planet_stats->{id},'MiningMinistry');
    if (defined $mining_ministry) {
        my $mining_ministry_object = $self->build_object($mining_ministry);
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
    
    # Get searchable ores
    my $archaeology_ores = $self->request(
        object  => $archaeology_ministry_object,
        method  => 'get_ores_available_for_processing',
    );
    
    foreach my $ore (keys %ores) {
        # Local ore
        if (defined $archaeology_ores->{ore}{$ore}) {
            $ores{$ore} = $archaeology_ores->{ore}{$ore};
        # This ore has been imported
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
            
            #$self->clear_cache('body/'.$planet_stats->{id}.'/buildings');
            
            return;
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
