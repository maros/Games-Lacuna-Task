#!/usr/bin/env perl

use Module::Build;

my $build = Module::Build->new(
    module_name => 'Games::Lacuna::Task',
    license     => 'perl',
    dist_author => 'Maroš Kollár <maros@cpan.org>',
    requires    => {
        'perl'                          => '5.10.1',

        'Moose'                         => '0',

        'Games::Lacuna::Client'         => '0.002',

        'DBI'                           => 0,
        'DBD::SQLite'                   => 0,

        'Path::Class'                   => 0,
        'MooseX::Getopt'                => 0,
        'MooseX::Types::Path::Class'    => 0,
        'MooseX::Role::Parameterized'   => 0,

        'YAML::Any'                     => 0,
        'LWP'                           => 0,
        'Text::CSV'                     => 0,
        'JSON'                          => 0,
        
        'Term::ANSIColor'               => 0,
        'IO::Interactive'               => 0,

        'Digest::MD5'                   => 0,
        'Unicode::Normalize'            => 0,
        'DateTime'                      => 0,
        'Try::Tiny'                     => 0,

        'Email::Stuff'                  => 0,
        'Text::Table'                   => 0,
    },
);
$build->create_build_script;
