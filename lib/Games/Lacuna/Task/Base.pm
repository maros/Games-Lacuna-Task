# ============================================================================
package Games::Lacuna::Task::Base;
# ============================================================================

use 5.010;

use Moose;

use Games::Lacuna::Task::Types;
use Games::Lacuna::Task::Meta::Class::Trait::NoAutomatic;
use Games::Lacuna::Task::Constants;

with qw(Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Logger);

use Module::Pluggable 
    search_path => ['Games::Lacuna::Task::Action'],
    sub_name => '_all_actions';

sub all_actions {
    _all_actions()
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;