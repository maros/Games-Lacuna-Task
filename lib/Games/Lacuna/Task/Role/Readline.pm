package Games::Lacuna::Task::Role::Readline;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Term::ANSIColor qw(color);
use Term::ReadLine;
use Games::Lacuna::Task::Utils qw(pretty_dump);

use Moose::Role;

sub sayline {
    my ($self,$line) = @_;
    $line ||= '-';
    say $line x $Games::Lacuna::Task::Constants::SCREEN_WIDTH;
}

sub saycolor {
    my ($self,$color,@msgs) = @_;
    
    @msgs = map { pretty_dump($_) } @msgs;
    
    my $format = shift(@msgs) // '';
    my $logmessage = sprintf( $format, map { $_ // 'UNDEF' } @msgs );
    
    say color($color).$logmessage.color("reset");
}

sub readline {
    my ($self,$prompt,$expect) = @_;
    
    state $term ||= Term::ReadLine->new($prompt);
    while (defined (my $response = $term->readline($prompt.' '))) {
        if (defined $expect) {
            return $response
                if $response =~ $expect;
        } else {
            return $response
        }
    }
}

1;