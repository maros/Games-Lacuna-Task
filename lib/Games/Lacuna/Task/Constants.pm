package Games::Lacuna::Task::Constants;

use strict;
use warnings;

# do not change order
our @RESSOURCES = qw(water ore energy);

our @ORES = qw(
    fluorite 
    anthracite 
    zircon 
    chromite 
    gypsum 
    sulfur 
    chalcopyrite 
    gold 
    trona 
    methane 
    magnetite 
    halite 
    rutile 
    goethite 
    bauxite
    kerogen
    uraninite
    beryl
    galena
    monazite
);

our %CARGO = (
    ship    => 50000,
    glyph   => 100,
    plan    => 10000,
);

1;