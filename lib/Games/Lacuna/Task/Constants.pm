package Games::Lacuna::Task::Constants;

use strict;
use warnings;

# do not change order
our @RESOURCES = qw(water ore energy food);

our %CARGO = (
    ship    => 50_000,
    glyph   => 100,
    plan    => 10_000,
);

our $WIDTH = 78;

our $RPC_LIMIT = 10_000;

1;