package Games::Lacuna::Task::Types;

use strict;
use warnings;

use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;
use Path::Class::File;

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