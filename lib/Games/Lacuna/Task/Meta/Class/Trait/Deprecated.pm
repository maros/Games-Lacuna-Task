# ============================================================================
package Games::Lacuna::Task::Meta::Class::Trait::Deprecated;
# ============================================================================
use utf8;
use 5.0100;

use Moose::Role;

sub deprecated { 1 }

package Moose::Meta::Class::Custom::Trait::Deprecated;
sub register_implementation { 'Games::Lacuna::Task::Meta::Class::Trait::Deprecated' }

no Moose::Role;
1;