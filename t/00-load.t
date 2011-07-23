#!*perl*

use Test::More tests => 31;


BEGIN {
	use_ok( 'Games::Lacuna::Task' );
}

diag( "Testing Games::Lacuna::Task Games::Lacuna::Task->VERSION, Perl $], $^X" );

use_ok( 'Games::Lacuna::Task::Action' );
use_ok( 'Games::Lacuna::Task::Action::Archaeology' );
use_ok( 'Games::Lacuna::Task::Action::Astronomy' );
use_ok( 'Games::Lacuna::Task::Action::Bleeder' );
use_ok( 'Games::Lacuna::Task::Action::Dispose' );
use_ok( 'Games::Lacuna::Task::Action::Excavate' );
use_ok( 'Games::Lacuna::Task::Action::Glyph' );
use_ok( 'Games::Lacuna::Task::Action::Intelligence' );
use_ok( 'Games::Lacuna::Task::Action::Mining' );
use_ok( 'Games::Lacuna::Task::Action::Recycle' );
use_ok( 'Games::Lacuna::Task::Action::Repair' );
use_ok( 'Games::Lacuna::Task::Action::ReportIncoming' );
use_ok( 'Games::Lacuna::Task::Action::Spy' );
use_ok( 'Games::Lacuna::Task::Action::Trade' );
use_ok( 'Games::Lacuna::Task::Action::Upgrade' );
use_ok( 'Games::Lacuna::Task::Action::UpgradeResource' );
use_ok( 'Games::Lacuna::Task::Action::Vote' );
use_ok( 'Games::Lacuna::Task::Action::WasteMonument' );
use_ok( 'Games::Lacuna::Task::Cache' );
use_ok( 'Games::Lacuna::Task::Client' );
use_ok( 'Games::Lacuna::Task::Constants' );
use_ok( 'Games::Lacuna::Task::Meta::Attribute::Trait::NoIntrospection' );
use_ok( 'Games::Lacuna::Task::Role::Captcha' );
use_ok( 'Games::Lacuna::Task::Role::Client' );
use_ok( 'Games::Lacuna::Task::Role::Helper' );
use_ok( 'Games::Lacuna::Task::Role::Logger' );
use_ok( 'Games::Lacuna::Task::Role::Notify' );
use_ok( 'Games::Lacuna::Task::Role::Ships' );
use_ok( 'Games::Lacuna::Task::Role::Stars' );
use_ok( 'Games::Lacuna::Task::Types' );
