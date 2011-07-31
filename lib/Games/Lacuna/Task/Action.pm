package Games::Lacuna::Task::Automator;

use 5.010;

use Moose;
with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Helper
    Games::Lacuna::Task::Role::Logger
    Games::Lacuna::Task::Role::PlanetRun
    );

__PACKAGE__->meta->make_immutable;
no Moose;
1;
