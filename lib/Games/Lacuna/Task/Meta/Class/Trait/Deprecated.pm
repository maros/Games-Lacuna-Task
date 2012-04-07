# ============================================================================
package Games::Lacuna::Task::Meta::Class::Trait::Deprecated;
# ============================================================================

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;

sub deprecated { 1 }

package Moose::Meta::Class::Custom::Trait::Deprecated;
sub register_implementation { 'Games::Lacuna::Task::Meta::Class::Trait::Deprecated' }

no Moose::Role;
1;