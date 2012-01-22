package Games::Lacuna::Task::Upgrade;

use 5.010;

use Moose;
with qw(Games::Lacuna::Task::Role::Logger);

our $VERSION = "2.01";

has 'storage' => (
    is              => 'ro',
    isa             => 'DBI::db',
    required        => 1,
);

has 'current_version' => (
    is              => 'rw',
    isa             => 'Num',
    lazy_build      => 1,
    required        => 1,
);

has 'latest_version' => (
    is              => 'ro',
    isa             => 'Num',
    default         => $VERSION,
    required        => 1,
);

sub _build_current_version {
    my ($self) = @_;
    
    my ($current_version) = $self->storage->selectrow_array('SELECT value FROM meta WHERE key = ?',{},'database_version');
    $current_version ||= 2.00;
    return $current_version;
}

sub run {
    my ($self) = @_;
    
    return
        if $self->current_version == $self->latest_version;
    
    my $storage = $self->storage;
    
    $self->log('info',"Upgrading storage from version %.2f to %.2f",$self->current_version(),$self->latest_version);
    
    my @sql;
    
    if ($self->current_version() < 2.01) {
        $self->log('debug','Upgrade for 2.00->2.01');
        
        push(@sql,'ALTER TABLE star RENAME TO star_old');
        
        push(@sql,'CREATE TABLE IF NOT EXISTS star (
            id INTEGER NOT NULL PRIMARY KEY,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            name TEXT NOT NULL,
            zone TEXT NOT NULL,
            last_checked INTEGER,
            is_probed INTEGER,
            is_known INTEGER
        )');
        
        push(@sql,'INSERT INTO star (id,x,y,name,zone,last_checked,is_probed,is_known) SELECT id,x,y,name,zone,last_checked,probed,probed FROM star_old');
        
        push(@sql,'DROP TABLE star_old');
        
        push(@sql,'DELETE FROM cache');
    }
    
    if (scalar @sql) {
        foreach my $sql (@sql) {
            $storage->do($sql)
                or $self->abort('Could not excecute sql %s: %s',$sql,$storage->errstr);
        }
    }
    
    $self->current_version($self->latest_version);
    $storage->do('INSERT OR REPLACE INTO meta (key,value) VALUES (?,?)',{},'database_version',$self->latest_version);
    
    return;
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;