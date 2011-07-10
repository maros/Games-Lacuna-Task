package Games::Lacuna::Task::Action::WasteMonument;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Building',
    'Games::Lacuna::Task::Role::Waste',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['dispose_percentage'] };

our @WASTE_MONUMENTS = qw(spacejunkpark pyramidjunksculpture greatballofjunk metaljunkarches junkhengesculpture);

#has 'demolish_waste_monument' => (
#    isa             => 'Bool',
#    is              => 'rw',
#    required        => 1,
#    default         => 0,
#    documentation   => 'Demolish old waste monuments',
#);

sub description {
    return q[This task automates the building of waste monuments];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    return
        if $self->university_level < 21;
    
    # Get stored waste
    my $waste_filled = ($planet_stats->{waste_stored} / $planet_stats->{waste_capacity}) * 100;
    my $waste_disposeable = $self->disposeable_waste($planet_stats);
    
    # Check if waste is overflowing
    return 
        if ($waste_filled < $self->dispose_percentage);
    
    my $buildable_spot = $self->find_buildspot($planet_stats);
    
    return 
        if scalar @{$buildable_spot} == 0;
    
    my $body_object = $self->build_object('Body', id => $planet_stats->{id});
    
    my $buildable_data = $self->request(
        object  => $body_object,
        method  => 'get_buildable',
        params  => [ $buildable_spot->[0][0],$buildable_spot->[0][1],'Waste' ],
    );
    
    my @buildable_monuments;
    
    BUILDABLE:
    foreach my $building (values %{$buildable_data->{buildable}}) {
        my $building_url = $building->{url};
        $building_url =~ s/^\///;
        
        next BUILDABLE
            unless $building_url ~~ \@WASTE_MONUMENTS;
        
        next BUILDABLE
            if $building->{build}{cost}{waste} > $waste_disposeable;
        
        next BUILDABLE
            unless $building->{build}{can};
            
        push(@buildable_monuments,{
            name    => $building->{name},
            url     => $building->{url},
            waste   => $building->{build}{cost}{waste},
        });
    }
    
    return
        unless (scalar @buildable_monuments);
    
    @buildable_monuments = sort { $a->{waste} <=> $b->{waste} } @buildable_monuments;
    
    my $waste_monument_object = $self->build_object($buildable_monuments[0]->{url});
    
    $self->log('notice',"Building %s on %s",$buildable_monuments[0]->{name},$planet_stats->{name});
    
    $self->request(
        object  => $waste_monument_object,
        method  => 'build',
        params  => [ $planet_stats->{id}, $buildable_spot->[0][0],$buildable_spot->[0][1]],
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;