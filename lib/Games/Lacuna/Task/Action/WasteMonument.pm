package Games::Lacuna::Task::Action::WasteMonument;

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Building',
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
    my $waste = $planet_stats->{waste_stored};
    my $waste_capacity = $planet_stats->{waste_capacity};
    my $waste_filled = ($waste / $waste_capacity) * 100;
    
    warn $waste_filled;
    
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
            unless $building->{build}{can};
            
        push(@buildable_monuments,{
            url     => $building->{url},
            waste   => $building->{build}{cost}{waste},
        });
    }
    
    return
        unless (scalar @buildable_monuments);
    
    @buildable_monuments = sort { $a->{waste} <=> $b->{waste} } @buildable_monuments;
    
    my $waste_monument_object = $self->build_object($buildable_monuments[0]->{url});
    
    $self->request(
        object  => $waste_monument_object,
        method  => 'build',
        params  => [ $planet_stats->{id}, $buildable_spot->[0][0],$buildable_spot->[0][1]],
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;