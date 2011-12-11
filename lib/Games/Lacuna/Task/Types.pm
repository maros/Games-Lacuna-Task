package Games::Lacuna::Task::Types;

use strict;
use warnings;

use Games::Lacuna::Client::Types qw(ore_types food_types);

use Path::Class::File;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;
use Games::Lacuna::Task::Constants;

subtype 'Lacuna::Task::Type::Ore' 
    => as enum([ ore_types() ])
    => message { "Not a valid ore '$_'" };

subtype 'Lacuna::Task::Type::Food' 
    => as enum([ food_types() ])
    => message { "No valid food '$_'" };

subtype 'Lacuna::Task::Type::Coordinate' 
    => as 'ArrayRef[Int]'
    => where { scalar(@$_) == 2 }
    => message { "Not a valid coordinate".Data::Dumper::Dumper($_); };

coerce 'Lacuna::Task::Type::Coordinate' 
    => from 'Str'
    => via {
        return [ split(/[;,x]/) ];
    };

MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'Lacuna::Task::Type::Coordinate' => '=s'
);

#subtype 'Lacuna::Task::Type::File'
#    => as class_type('Path::Class::File')
#    => where { -f $_ && -r _ }
#    => message { "Could not find/read file '$_'" };
#
#subtype 'Lacuna::Task::Type::Dir'
#    => as class_type('Path::Class::Dir')
#    => where { -d $_ && -r _ }
#    => message { "Could not find/read directory '$_'" };


1;
