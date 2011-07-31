# ============================================================================
package Games::Lacuna::Task::ActionProto;
# ============================================================================

use 5.010;

use Moose;
with qw(Games::Lacuna::Task::Role::Config
    Games::Lacuna::Task::Role::Client
    Games::Lacuna::Task::Role::Logger);

use List::Util qw(max);

use Games::Lacuna::Task::Types;
use Games::Lacuna::Task::Meta::Attribute::Trait::NoIntrospection;
use Games::Lacuna::Task::Constants;
use Games::Lacuna::Task::Utils qw(name_to_class class_to_name);

use Module::Pluggable 
    search_path => ['Games::Lacuna::Task::Action'],
    sub_name => 'all_actions';

sub run {
    my ($self) = @_;
    
    my $command = shift(@ARGV);
    my $class = name_to_class($command);
    
    if (! defined $command) {
        say "Missing command";
        $self->print_usage();
    } elsif ($command ~~ [qw(help ? --help -h -?)]) {
        $self->print_usage();
    } elsif (! ($class ~~ [all_actions()])) {
        say "Unknown command '$command'";
        $self->print_usage();
    } else {
        Class::MOP::load_class($class);
        
        my $pa = $class->process_argv();
        my $commandline_params = $pa->cli_params();
        $self->database($commandline_params->{database})
            if defined $commandline_params->{database};
        my $task_config = $self->task_config($command);
        
        my $object = $class->new(
            ARGV        => $pa->argv_copy,
            extra_argv  => $pa->extra_argv,
            ( $pa->usage ? ( usage => $pa->usage ) : () ),
            %{ $task_config }, # explicit params to ->new
            %{ $pa->cli_params }, # params from CLI
        );
        
        $object->execute;
    }
}

sub print_usage {
    my ($self) = @_;
    
    my $caller = Path::Class::File->new($0)->basename;
    
    my @commands;
    push(@commands,['help','Prints this usage information']);
    
    foreach my $class (all_actions()) {
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