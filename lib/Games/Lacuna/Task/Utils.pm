package Games::Lacuna::Task::Utils;

use strict;
use warnings;

use Unicode::Normalize;

use base qw(Exporter);
our @EXPORT_OK = qw(class_to_name name_to_class normalize_name); 

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
    my $name = shift;
    my $name_simple = Unicode::Normalize::decompose($name); 
    $name_simple =~ s/\p{NonSpacingMark}//g;
    return uc($name_simple);
}

1;