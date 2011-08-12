package Games::Lacuna::Task::Table;

use 5.010;

use Moose;

has 'headline' => (
    is              => 'rw',
    isa             => 'Str',
    predicate       => 'has_headline',
);

has 'columns' => (
    is              => 'rw',
    isa             => 'ArrayRef[Str]',
    required        => 1,
);

has 'data' => (
    is              => 'rw',
    isa             => 'ArrayRef[HashRef]',
    traits          => ['Array'],
    default         => sub { [] },
    handles => {
        rows            => 'elements',
        add_row         => 'push',
    },
);

sub render_html {
    my ($self) = @_;
    
    my $rendered = '<div>';
    $rendered .= '<h2>'.$self->headline.'</h2>'
        if $self->has_headline;
    
    $rendered .= '<table witdh="100%"><thead><tr>';
    foreach my $column (@{$self->columns}) {
        $rendered .= '<th>'.$column.'</th>';
    }
    $rendered .= '</tr></thead><tbody>';
    foreach my $row ($self->rows) {
        $rendered .= '<tr>';
        foreach my $column (@{$self->columns}) {
            my $column_key = lc($column);
            $column_key =~ s/\s+/_/g;
            $rendered .= '<td>'.($row->{$column_key} // '').'</td>';
        }
        $rendered .= '</tr>';
    }
    $rendered .= '</tbody></table></div>';
    return $rendered;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;