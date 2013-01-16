package Games::Lacuna::Task::Utils;

use 5.010;
use strict;
use warnings;

our $VERSION = $Games::Lacuna::Task::VERSION;

use Unicode::Normalize qw(decompose);
use Scalar::Util qw(blessed);
use Time::Local qw(timegm);

use base qw(Exporter);
our @EXPORT_OK = qw(
    class_to_name
    name_to_class
    normalize_name
    clean_name
    distance 
    pretty_dump
    parse_ship_type
    parse_date
    format_date
    format_duration
); 

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
    
    return 
        unless defined $name;
    
    my @parts = map { ucfirst(lc($_)) } 
        split (/[_ ]/,$name);
    
    my $class = 'Games::Lacuna::Task::Action::'.join ('',@parts);
    
    return $class;
}

sub normalize_name {
    my ($name) = @_;
    
    return
        unless defined $name;
    
    return uc(clean_name($name));
}

sub clean_name {
    my ($name) = @_;
    
    return
        unless defined $name;
    
    my $name_simple = decompose($name); 
    $name_simple =~ s/\p{NonSpacingMark}//g;
    
    $name_simple =~ s/^\s+//g;
    $name_simple =~ s/\s+$//g;
    
    return $name_simple;
}

sub distance {
    my ($x1,$y1,$x2,$y2) = @_;
    
    return int(sqrt( ($x1 - $x2)**2 + ($y1 - $y2)**2 ));
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

sub parse_ship_type {
    my ($name) = @_;
    
    return
        unless defined $name;
    
    $name = lc($name);
    $name =~ s/\s+/_/g;
    $name =~ s/(vi)$/6/i;
    $name =~ s/(iv)$/4/i;
    $name =~ s/(v)$/5/i;
    $name =~ s/(i{1,3})$/length($1)/ei;
    $name =~ s/_([1-6])$/$1/;
    
    return $name;
}

sub parse_date {
    my ($date) = @_;
    
    return
        unless defined $date;
    
    if ($date =~ m/^
        (?<day>\d{2}) \s
        (?<month>\d{2}) \s
        (?<year>20\d{2}) \s
        (?<hour>\d{2}) :
        (?<minute>\d{2}) :
        (?<second>\d{2}) \s
        \+(?<timezoneoffset>\d{4})
        $/x) {
        
        warn('Unexpected timezone offset '.$+{timezoneoffset})
            if $+{timezoneoffset} != 0;
            
        my @params = map { $+{$_} } qw(second minute hour day month year);
        $params[4]--; #month index
        
        return timegm(@params);
    }
    
    return;
}

sub format_date {
    my ($timestamp) = @_;
    
    return
        unless defined $timestamp && $timestamp =~ m/^\d+$/;
    
    my ($sec,$min,$hour,$mday,$mon,$year) = gmtime($timestamp);
    $year += 1900;
    $mon++;
    
    return sprintf('%04i.%02i.%02i %02i:%02i',$year,$mon,$mday,$hour,$min);
}

sub format_duration {
    my ($timestamp) = @_;
    
    return
        unless defined $timestamp && $timestamp =~ m/^\d+$/;
    
    $timestamp -= time();
    
    return 
        if $timestamp <= 0;
    
    my $days = int($timestamp / (60 * 60 * 24));
    $timestamp -= $days * (60 * 60 * 24);
    
    my $hours = int($timestamp / (60 * 60));
    $timestamp -= $hours * (60 * 60);
    
    my $minutes = int($timestamp / 60);
    
    if ($days > 0) {
        return sprintf('%id %ih',$days,$hours);   
    } else {
        return sprintf('%ih %im',$hours,$minutes);   
    }
}

1;

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Utils - Helper functions for Games::Lacuna::Task

=head1 SYNOPSIS

    use Games::Lacuna::Task::Utils qw(class_to_name);

=head1 FUNCTIONS

No functions are exported by default.



=head3 class_to_name

Class name to moniker (lowercase, uderscore separated)

=head3 name_to_class

Moniker to class name (camel case, prefixed with Games::Lacuna::Task::Action::)

=head3 distance

 my $dist = distance($x1,$y1,$x2,$y2);

Calculates map distance

=head3 pretty_dump

 say pretty_dump($value);

Stringifies any value

=head3 normalize_name

 my $normalized = normalize_name($name);

Removes diacritic marks and uppercases a string for better comparability

=head3 clean_name

 my $cleaned = clean_name($name);
 
Removes all diacritic marks from a string eg. turining "Käse" into "Kase"

=head3 parse_ship_type

 my $ship_type = parse_ship_type($human_type);

Converts a human ship name into the ship type

=head3 parse_date

Returns a epoch timestamp for the given timestamp from the api response

=head3 format_date

Formats an epoch timestamp

=head3 format_duration

Formats a duration

=cut