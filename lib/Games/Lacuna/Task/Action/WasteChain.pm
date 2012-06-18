package Games::Lacuna::Task::Action::WasteChain;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use List::Util qw(min);

use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Waste',
    'Games::Lacuna::Task::Role::PlanetRun',
    'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['dispose_percentage','keep_waste_hours'] };

sub description {
    return q[Manage waste chains];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    # Get stored waste
    my $waste_stored = $planet_stats->{waste_stored};
    my $waste_capacity = $planet_stats->{waste_capacity};
    my $waste_filled = ($waste_stored / $waste_capacity) * 100;
    my $waste_disposeable = $self->disposeable_waste($planet_stats);
    
    # Get trade ministry
    my ($trade) = $self->find_building($planet_stats->{id},'Trade');
    
    return 
        unless $trade;
    
    my $trade_object = $self->build_object($trade);
    
    my $waste_chain_data = $self->request(
        object  => $trade_object,
        method  => 'view_waste_chains',
    );
    
    my $waste_chain = $waste_chain_data->{waste_chain}[0];

    my $new_waste_chain_hour;
    # Start disposal
    if ($waste_filled > $self->dispose_percentage) {
        $new_waste_chain_hour = int($waste_chain->{waste_hour} * $waste_chain->{percent_transferred} / 100);
    # Stop disposal
    } else {
        $new_waste_chain_hour = $planet_stats->{waste_hour} + $waste_chain->{waste_hour};
    }
    
    $new_waste_chain_hour = 0
        if $new_waste_chain_hour < 0;
        
    if ($new_waste_chain_hour != $waste_chain->{waste_hour}) {
        $self->log('info','Updating waste chain on %s to dispose %i waste per hour',$planet_stats->{name},$new_waste_chain_hour);
        $self->request(
            object  => $trade_object,
            method  => 'update_waste_chain',
            params  => [ $waste_chain->{id}, $new_waste_chain_hour],
        );
    }
    
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
