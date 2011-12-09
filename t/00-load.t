#!*perl*

use Test::More tests => 62;

BEGIN {
	use_ok( 'Games::Lacuna::Task' );
}

diag( "Testing Games::Lacuna::Task Games::Lacuna::Task->VERSION, Perl $], $^X" );

use_ok( 'Games::Lacuna::Task::Action' );
use_ok( 'Games::Lacuna::Task::Action::Archaeology' );
use_ok( 'Games::Lacuna::Task::Action::Astronomy' );
use_ok( 'Games::Lacuna::Task::Action::Bleeder' );
use_ok( 'Games::Lacuna::Task::Action::BuildVrbansk' );
use_ok( 'Games::Lacuna::Task::Action::CollectExcavatorBooty' );
use_ok( 'Games::Lacuna::Task::Action::CounterIntelligence' );
use_ok( 'Games::Lacuna::Task::Action::Defence' );
use_ok( 'Games::Lacuna::Task::Action::EmpireReport' );
use_ok( 'Games::Lacuna::Task::Action::Excavate' );
use_ok( 'Games::Lacuna::Task::Action::FetchSpy' );
use_ok( 'Games::Lacuna::Task::Action::Mining' );
use_ok( 'Games::Lacuna::Task::Action::Mission' );
use_ok( 'Games::Lacuna::Task::Action::OptimizeProbes' );
use_ok( 'Games::Lacuna::Task::Action::Repair' );
use_ok( 'Games::Lacuna::Task::Action::ReportIncoming' );
use_ok( 'Games::Lacuna::Task::Action::SendSpy' );
use_ok( 'Games::Lacuna::Task::Action::Spy' );
use_ok( 'Games::Lacuna::Task::Action::StarCache' );
use_ok( 'Games::Lacuna::Task::Action::StationPlanBuilder' );
use_ok( 'Games::Lacuna::Task::Action::Trade' );
use_ok( 'Games::Lacuna::Task::Action::Upgrade' );
use_ok( 'Games::Lacuna::Task::Action::UpgradeBuilding' );
use_ok( 'Games::Lacuna::Task::Action::Vote' );
use_ok( 'Games::Lacuna::Task::Action::Vrbansk' );
use_ok( 'Games::Lacuna::Task::Action::WasteDispose' );
use_ok( 'Games::Lacuna::Task::Action::WasteMonument' );
use_ok( 'Games::Lacuna::Task::Action::WasteProduction' );
use_ok( 'Games::Lacuna::Task::Action::WasteRecycle' );
use_ok( 'Games::Lacuna::Task::ActionProto' );
use_ok( 'Games::Lacuna::Task::Base' );
use_ok( 'Games::Lacuna::Task::Cache' );
use_ok( 'Games::Lacuna::Task::Client' );
use_ok( 'Games::Lacuna::Task::Constants' );
use_ok( 'Games::Lacuna::Task::Meta::Attribute::Trait::NoIntrospection' );
use_ok( 'Games::Lacuna::Task::Meta::Class::Trait::NoAutomatic' );
use_ok( 'Games::Lacuna::Task::Report::Battle' );
use_ok( 'Games::Lacuna::Task::Report::Fleet' );
use_ok( 'Games::Lacuna::Task::Report::Glyph' );
use_ok( 'Games::Lacuna::Task::Report::Inbox' );
use_ok( 'Games::Lacuna::Task::Report::Incoming' );
use_ok( 'Games::Lacuna::Task::Report::Intelligence' );
use_ok( 'Games::Lacuna::Task::Report::Mining' );
use_ok( 'Games::Lacuna::Task::Role::Building' );
use_ok( 'Games::Lacuna::Task::Role::Captcha' );
use_ok( 'Games::Lacuna::Task::Role::Client' );
use_ok( 'Games::Lacuna::Task::Role::CommonAttributes' );
use_ok( 'Games::Lacuna::Task::Role::Helper' );
use_ok( 'Games::Lacuna::Task::Role::Intelligence' );
use_ok( 'Games::Lacuna::Task::Role::Introspect' );
use_ok( 'Games::Lacuna::Task::Role::Logger' );
use_ok( 'Games::Lacuna::Task::Role::Notify' );
use_ok( 'Games::Lacuna::Task::Role::PlanetRun' );
use_ok( 'Games::Lacuna::Task::Role::RPCLimit' );
use_ok( 'Games::Lacuna::Task::Role::Ships' );
use_ok( 'Games::Lacuna::Task::Role::Stars' );
use_ok( 'Games::Lacuna::Task::Role::Storage' );
use_ok( 'Games::Lacuna::Task::Role::Waste' );
use_ok( 'Games::Lacuna::Task::Table' );
use_ok( 'Games::Lacuna::Task::Types' );
use_ok( 'Games::Lacuna::Task::Utils' );
