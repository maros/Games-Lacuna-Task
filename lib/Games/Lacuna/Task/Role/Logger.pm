package Games::Lacuna::Task::Role::Logger;

use 5.010;
use Moose::Role;

use IO::Interactive qw(is_interactive);
use Term::ANSIColor;

our @LEVELS = qw(debug info notice warn error);

has 'loglevel' => (
    is              => 'ro',
    isa             => Moose::Util::TypeConstraints::enum(\@LEVELS),
    traits          => ['KiokuDB::DoNotSerialize','NoIntrospection'],
    default         => 'info',
    documentation   => 'Print all messages equal or above the given level [Default: info, Available: '.join(',',@LEVELS).']',
);

sub log {
    my ( $self, @msgs ) = @_;

    binmode STDOUT, ":utf8";

    my $level_name = shift(@msgs)
        if $msgs[0] ~~ \@LEVELS;
    
    @msgs = map { _pretty_dump($_) } @msgs;
    
    my $format = shift(@msgs) // '';
    my $logmessage = sprintf( $format, map { $_ // 'UNDEF' } @msgs );
    
    if ( $INC{'Test/More.pm'} ) {
        ( my $file = $0 ) =~ s{/}{_}g;
        $file =~ s/(^t_)|(\.t$)//;
        $file = 't/' . lc($file) . '.log';
        open( my $fh, ">>:encoding(utf8)", $file )
            ||  warn "Cannot write to test logger $file: $!";
        say $fh join( '; ', ( $level_name, @msgs ) );
        close $fh;
    }
    else {
        if (is_interactive()) {
            my ($level_pos) = grep { $LEVELS[$_] eq $level_name } 0 .. $#LEVELS;
            my ($level_max) = grep { $LEVELS[$_] eq $self->loglevel } 0 .. $#LEVELS;
            if ($level_pos >= $level_max) {
                given ($level_name) {
                    when ('error') {
                        print color 'bold red';
                    }
                    when ('warn') {
                        print color 'bold yellow';
                    }
                    when ('notice') {
                        print color 'bold magenta';
                    }
                    when ('info') {
                        print color 'bold cyan';
                    }
                    when ('debug') {
                        print color 'bold white';
                    }
                }
                printf "%6s: ",$level_name;
                print color 'reset';
                say $logmessage;
            }
        }
    }
}

sub _pretty_dump {
    my $value = shift;
    return $value
        unless ref $value;
    return $value->stringify
        if blessed $value && $value->can('stringify');
    return $value->message
        if blessed $value && $value->can('message');
    my $dump = Data::Dumper::Dumper($value);
    chomp($dump);
    $dump =~ s/^\$VAR1\s=\s(.+);$/$1/s;
    return $dump;
}


=encoding utf8

=head1 NAME

Games::Lacuna::Role::Logger - Prints log messages

=head1 ACCESSORS

=head2 loglevel

Specify the loglevel. Will print all log messages equal or above the given
level if running in an interactive shell. 

=head1 METHODS

=head2 log

Print a log message. You can use the sprintf syntax.

 $self->log($loglevel,$message,@sprintf_params);

=cut

no Moose::Role;
1;
