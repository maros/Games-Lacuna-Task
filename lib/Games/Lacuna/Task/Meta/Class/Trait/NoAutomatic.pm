# ============================================================================
package Games::Lacuna::Task::Meta::Class::Trait::NoAutomatic;
# ============================================================================

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;

sub no_automatic { 1 }

package Moose::Meta::Class::Custom::Trait::NoAutomatic;
sub register_implementation { 'Games::Lacuna::Task::Meta::Class::Trait::NoAutomatic' }

no Moose::Role;
1;