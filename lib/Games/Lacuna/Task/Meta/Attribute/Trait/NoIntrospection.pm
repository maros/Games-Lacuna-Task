# ============================================================================
package Games::Lacuna::Task::Meta::Attribute::Trait::NoIntrospection;
# ============================================================================
use utf8;
use 5.0100;

use Moose::Role;

package Moose::Meta::Attribute::Custom::Trait::NoIntrospection;
sub register_implementation { 'Games::Lacuna::Task::Meta::Attribute::Trait::NoIntrospection' }

no Moose::Role;
1;