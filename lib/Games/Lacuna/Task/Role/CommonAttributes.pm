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
};

1;