package Games::Lacuna::Task::Action::MissionSelect;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose -traits => 'NoAutomatic';
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Readline);

use YAML::Any qw(Dump);

has 'path' => (
    is              => 'rw',
    isa             => 'Path::Class::Dir',
    documentation   => q[Path to mission directory],
    required        => 1,
    coerce          => 1,
);

sub description {
    return q[Select missions for the mission task];
}

sub run {
    my ($self) = @_;
    
    my @selected;
    
    foreach my $file ($self->path->children) {
        next
            unless $file->stringify =~ m/\.(mission|part\d+)$/;
        
        my $mission_data = $file->slurp;
        $mission_data =~ s/#.+//gm;
        my $mission =eval {
            $Games::Lacuna::Task::Storage::JSON->decode($mission_data);
        };
        if ($@) {
            $self->log('warn','Skip broken mission file %s',$file->stringify);
            next;
        }
        
        next
            if $mission->{max_university_level} > $self->university_level;
        
        $self->sayline();
        $self->saycolor('magenta',$mission->{name});
        $self->saycolor('cyan','Objective:');
        $self->format_mission($mission->{mission_objective});
        $self->saycolor('cyan','Reward:');
        $self->format_mission($mission->{mission_reward});
        if ($self->readline("Select mission (y/n):",qr/^[yn]*$/i) =~ /^[yY]$/) {
            push(@selected,$mission->{name})
        }
    }
    
    $self->sayline();
    $self->saycolor(
        'magenta',
        'Please add the following lines to your %s/config.yml file',
        $self->configdir->stringify
    );
    say Dump({
        'mission' => {
            'missions' => \@selected
        },
        
    })      
}

sub format_mission {
    my ($self,$items) = @_;
    
    foreach my $type (keys %{$items}) {
        my $elements = $items->{$type};
        
        if (ref($elements) eq 'ARRAY') {
            foreach my $element (@{$elements}) {
                given ($type) {
                    when('glyphs') {
                        say '  - '.$element.' glyph';
                    } 
                    when('ships') {
                        say '  - '.$element->{type}.' ship';
                    }
                    when('plans') {
                        my $type = $element->{classname};
                        $type =~ s/^(.+)::([^:]+)::([^:]+)$/$2 - $3/;
                        my $level = $element->{level};
                        $level .= '+'.$element->{extra_build_level}
                            if $element->{extra_build_level};
                        
                        say '  - '
                            .$type
                            .' ('
                            .$level
                            .') plan';
                    }
                    when ('fleet_movement') {
                        say '  - fleet movement';
                    }
                }
            }
        } elsif (ref($elements) eq 'HASH') {
            foreach my $element (keys %{$elements}) {
                say '  - '.$elements->{$element}.' '.$element;
            }
        } else {
            say '  - '.$elements.' '.$type;
        }
    }
    
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;