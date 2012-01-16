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


has 'lockfile' => (
    is              => 'rw',
    isa             => 'Path::Class::File',
    traits          => ['NoGetopt'],
    lazy_build      => 1,
);

sub _build_lockfile {
    my ($self) = @_;
    
    return $self->configdir->file('lacuna.pid');
}

sub BUILD {
    my ($self) = @_;
    
    my $lockcounter = 0;
    my $lockfile = $self->lockfile;
    
    # Check for lockfile
    while (-e $lockfile) {
        my ($pid) = $lockfile->slurp(chomp => 1);
        
        if ($lockcounter > 10) {
            $self->abort('Could not aquire lock');
        } else {
            $self->log('warn','Another process is currently running. Waiting until it has finished');
        }
        $lockcounter++;
        sleep 60;
    }
    
    # Write lock file
    my $lockfh = $lockfile->openw();
    print $lockfh $$;
    $lockfh->close;
}

sub DEMOLISH {
    my ($self) = @_;
    
    $self->lockfile->remove
        if -e $self->lockfile;
}

sub all_actions {
    _all_actions()
}



__PACKAGE__->meta->make_immutable;
no Moose;
1;