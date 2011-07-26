# ============================================================================
package Games::Lacuna::Task::CommandProto;
# ============================================================================

use 5.010;

use Moose;

use List::Util qw(max);

use Games::Lacuna::Task::Command;
use Games::Lacuna::Task::Utils qw(name_to_class class_to_name);

use Module::Pluggable 
    search_path => ['Games::Lacuna::Task::Command'],
    sub_name => 'all_commands';

sub run {
    my ($self) = @_;
    
    my $command = shift(@ARGV);
    
    if (! defined $command) {
        say "Missing command";
        $self->usage();
    } elsif ($command ~~ [qw(help ? --help -h -?)]) {
        $self->usage();
    } elsif (! $command ~~ [all_commands()]) {
        say "Unknown command '$command'";
        $self->usage();
    } else {
        my $class = name_to_class($command,'Command');
        Class::MOP::load_class($class);
        my $object = $class->new_with_options;
        $object->execute();
    }
}

sub usage {
    my ($self) = @_;
    
    my $caller = Path::Class::File->new($0)->basename;
    
    my @commands;
    push(@commands,['help','Prints this usage information']);
    
    foreach my $class (all_commands()) {
        my $command = class_to_name($class);
        Class::MOP::load_class($class);
        push(@commands,[$command,$class->description]);
    }
    
    my $max_length = max(map { length($_->[0]) } @commands);
    my $description_length = $Games::Lacuna::Task::Constants::WIDTH - $max_length - 7;
    my $prefix_length = $max_length + 5 + 1;
    
    say "usage: $caller command [long options...]";
    say "help: $caller command --help";
    say "available commands:";
    foreach my $command (@commands) {
        my @lines = $self->_split_string($description_length,$command->[1]);
        say sprintf('    %-*s  %s',$max_length,$command->[0],shift(@lines));
        while (my $line = shift (@lines)) {
            say ' 'x $prefix_length.$line;
        }
    }
    
}

sub _split_string {
    my ($self, $maxlength, $string) = @_;
    
    return $string 
        if length $string <= $maxlength;

    my @lines;
    while (length $string > $maxlength) {
        my $idx = rindex( substr( $string, 0, $maxlength ), q{ }, );
        last unless $idx >= 0;
        push @lines, substr($string, 0, $idx);
        substr($string, 0, $idx + 1) = q{};
    }
    push @lines, $string;
    return @lines;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;