package Games::Lacuna::Task::Report::Vrbansk;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;
with qw(Games::Lacuna::Task::Role::Storage);

use Games::Lacuna::Client::Types qw(ore_types);

sub report_vrbansk {
    my ($self) = @_;
    
    my $table = Games::Lacuna::Task::Table->new(
        headline=> 'Halls of Vrbansk Report',
        columns => ['Planet','Plans'],
    );
    
    my $total = 0;
    foreach my $planet_id ($self->my_planets) {
       $total += $self->_report_vrbansk_body($planet_id,$table);
    }
    
    $table->add_row({
        planet          => 'Total',
        total           => $total,
    });
    
    return $table;
}

sub _report_vrbansk_body {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    my $plans_stored = $self->plans_stored($planet_id);
    my @buildings = $self->buildings_body($planet_stats);
    
    my ($plans) = 0;
    foreach my $plan (@{$plans_stored}) {
        next
            unless $plan->{name} eq 'Halls of Vrbansk';
        $plans = $plan->{quantity};
        last;
    }
    
    $table->add_row({
        planet          => $planet_stats->{name},
        total           => $plans,
    });
    
    return $plans;
}

no Moose::Role;
1;