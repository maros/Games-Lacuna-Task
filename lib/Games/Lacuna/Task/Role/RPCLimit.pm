package Games::Lacuna::Task::Role::RPCLimit;

use 5.010;
use Moose::Role;

has 'force' => (
    is              => 'rw',
    isa             => 'Bool',
    required        => 1,
    default         => 0,
    documentation   => 'Run action even if RPC limit is almost spent',
);

around 'run' => sub {
    my $orig = shift;
    my $self = shift;
    
    my $empire_stats = $self->empire_status;
    my $rpc_limit = int($Games::Lacuna::Task::Constants::RPC_LIMIT * 0.9);
    
    if ($empire_stats->{rpc_count} > $rpc_limit
        && ! $self->force) {
        my $task_name = Games::Lacuna::Task::Utils::class_to_name($self);
        $self->log('warn',"Skipping action %s because RPC limit is almost reached (%i of %i)",$task_name,$empire_stats->{rpc_count},$Games::Lacuna::Task::Constants::RPC_LIMIT);
    } else {
        return $self->$orig(@_);
    }
};

no Moose::Role;
1;

=encoding utf8

=head1 NAME

Games::Lacuna::Role::RPCLimit - Skip tasks if 90% RPC limit is reached

=cut