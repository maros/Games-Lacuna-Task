package Games::Lacuna::Task::Action::EmpireFind;

use 5.010;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Stars);

use Games::Lacuna::Task::Utils qw(normalize_name);
use Games::Lacuna::Task::Table;

has 'empire' => (
    is              => 'rw',
    isa             => 'ArrayRef[Str]',
    required        => 1,
    documentation   => 'Empire name you are looking for [Multiple]',
);

sub description {
    return q[Find all bodies owned by a given empire];
}

sub run {
    my ($self) = @_;
    
    #my $planet_stats = $self->my_body_status($self->home_planet_id);
    my $planet_stats = { x => 100, y => 200 };
    
    my $sth_empire = $self->storage_prepare('SELECT 
            id,
            name 
        FROM empire 
        WHERE name = ?
        OR normalized_name = ?');
    
    my %empires;
    
    foreach my $empire (@{$self->empire}) {
        $sth_empire->execute($empire,normalize_name($empire));
        while (my ($id,$name) = $sth_empire->fetchrow_array) {
            $empires{$id} = $name;
        }
    }
    
    $self->abort('Could nor find empires %s',join(', ',@{$self->empire}))
        unless scalar keys %empires;
    
    my $empire_query = join(',',(('?') x scalar keys %empires));
    
    my $sth_body = $self->storage_prepare('SELECT 
          body.id,
          body.x,
          body.y,
          body.orbit,
          body.size,
          body.name,
          body.type,
          body.empire,
          star.name AS star,
          distance_func(body.x,body.y,?,?) AS distance
        FROM body
        INNER JOIN star ON (body.star = star.id)
        WHERE empire IN ('.$empire_query.')
        ORDER BY distance ASC');
    
    $sth_body->execute($planet_stats->{x},$planet_stats->{y},keys %empires);
    
    my $table = Games::Lacuna::Task::Table->new({
        columns     => ['Name','X','Y','Type','Orbit','Size','Star','Empire','Distance'],
    });
    
    while (my $body = $sth_body->fetchrow_hashref) {
        $table->add_row({
            (map { ($_ => $body->{$_}) } qw(name x y orbit type orbit size star distance)),
            empire  => $empires{$body->{empire}},
        });
    }
    
    say $table->render_text;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;