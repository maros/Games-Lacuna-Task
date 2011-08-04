package Games::Lacuna::Task::Role::CommonAttributes;

use 5.010;
use MooseX::Role::Parameterized;

parameter 'attributes' => (
    isa      => 'ArrayRef[Str]',
    required => 1,
);

role {
    my $p = shift;

    if ('dispose_percentage' ~~ $p->attributes) {
        has 'dispose_percentage' => (
            isa     => 'Int',
            is      => 'rw',
            required=>1,
            default => 80,
            documentation => 'Dispose waste if waste storage is n-% full',
        );
    }

    if ('start_building_at' ~~ $p->attributes) {
        has 'start_building_at' => (
            isa     => 'Int',
            is      => 'rw',
            required=> 1,
            default => 0,
            documentation => 'Upgrade buildings if there are less than N buildings in the build queue',
        );
    }
    
    if ('plan_for_hours' ~~ $p->attributes) {
        has 'plan_for_hours' => (
            isa     => 'Num',
            is      => 'rw',
            required=> 1,
            default => 1,
            documentation => 'Plan N hours ahead',
        );
    }
    
    if ('keep_waste_hours' ~~ $p->attributes) {
        has 'keep_waste_hours' => (
            isa     => 'Num',
            is      => 'rw',
            required=> 1,
            default => 24,
            documentation => 'Keep enough waste for N hours',
        );
    }
};

1;

=encoding utf8

=head1 NAME

Games::Lacuna::Role::CommonAttributes - Attributes utilized by multiple actions

=head1 SYNOPSIS

 package Games::Lacuna::Task::Action::MyTask;
 use Moose;
 extends qw(Games::Lacuna::Task::Action);
 with 'Games::Lacuna::Task::Role::CommonAttributes' => { attributes => ['dispose_percentage'] };

=cut