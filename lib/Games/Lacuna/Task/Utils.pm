package Games::Lacuna::Task::Utils;

use strict;
use warnings;

use Unicode::Normalize qw(decompose);
use Scalar::Util qw(blessed);

use base qw(Exporter);
our @EXPORT_OK = qw(class_to_name name_to_class normalize_name distance pretty_dump); 

sub class_to_name {
    my ($class) = @_;
    
    $class = ref($class)
        if ref($class);
    $class =~ s/^.+::([^:]+)$/$1/;
    $class =~ s/(\p{Lower})(\p{Upper}\p{Lower})/$1_$2/g;
    $class = lc($class);
    return $class;
}

sub name_to_class {
    my ($name) = @_;
    
    my @parts = map { ucfirst(lc($_)) } 
        split (/_/,$name);
    
    my $class = 'Games::Lacuna::Task::Action::'.join ('',@parts);
    
    return $class;
}

sub normalize_name {
    my ($name) = @_;
    
    my $name_simple = decompose($name); 
    $name_simple =~ s/\p{NonSpacingMark}//g;
    return uc($name_simple);
}

sub distance {
    my ($x1,$y1,$x2,$y2) = @_;
    return sqrt( ($x1 - $x2)**2 + ($y1 - $y2)**2 );
}

sub pretty_dump {
    my ($value) = @_;
    
    return $value
        unless ref $value;
    return $value->stringify
        if blessed($value) && $value->can('stringify');
    return $value->message
        if blessed($value) && $value->can('message');
    my $dump = Data::Dumper::Dumper($value);
    chomp($dump);
    $dump =~ s/^\$VAR1\s=\s(.+);$/$1/s;
    return $dump;
}

1;