# Load the Module::Install bundled in ./inc/
use strict;
use inc::Module::Install 0.92;

# Define metadata
name            'Games-Lacuna-Task';
all_from        'lib/Games/Lacuna/Task.pm';

perl_version    '5.010';

# Specific dependencies
requires        'Moose'                         => 0;

requires        'Games::Lacuna::Client'         => 0;

requires        'KiokuDB'                       => 0;

requires        'Path::Class'                   => 0;
requires        'MooseX::Types::Path::Class'    => 0;

requires        'YAML'                          => 0;

requires        'Term::ReadKey'                 => 0;
requires        'Term::ANSIColor'               => 0;
requires        'IO::Interactive'               => 0;

install_script 'bin/lacuna_task';

WriteAll;