# ============================================================================
package Games::Lacuna::Task::Meta::Class::Trait::NoAutomatic;
# ============================================================================
use utf8;
use 5.0100;

use Moose::Role;

sub no_automatic { 1 }

package Moose::Meta::Class::Custom::Trait::NoAutomatic;
sub register_implementation { 'Games::Lacuna::Task::Meta::Class::Trait::NoAutomatic' }

no Moose::Role;
1;