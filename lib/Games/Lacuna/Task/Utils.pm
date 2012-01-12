package Games::Lacuna::Task::Utils;

use strict;
use warnings;

use Unicode::Normalize qw(decompose);
use Scalar::Util qw(blessed);

use base qw(Exporter);
our @EXPORT_OK = qw(
    class_to_name
    name_to_class
    normalize_name
    distance 
    pretty_dump
    parse_ship_type
    delta_date
    delta_date_format
    parse_date
    timestamp
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
    
    my $name_simple = decompose($name); 
    $name_simple =~ s/\p{NonSpacingMark}//g;
    return uc($name_simple);
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
    
    $name = lc($name);
    $name =~ s/\s+/_/g;
    $name =~ s/(vi)$/6/i;
    $name =~ s/(iv)$/4/i;
    $name =~ s/(v)$/5/i;
    $name =~ s/(i{1,3})$/length($1)/ei;
    $name =~ s/_([1-6])$/$1/;
    
    return $name;
}

sub timestamp {
    return DateTime->now->set_time_zone('UTC');
}

sub delta_date {
    my ($date) = @_;
    
    $date = parse_date($date)
        unless blessed($date) && $date->isa('DateTime');
    
    my $timestamp = timestamp();
    my $date_delta_ms = $timestamp->delta_ms( $date );
    
    return $date_delta_ms;
}

sub delta_date_format {
    my ($date) = @_;
    
    my $date_delta_ms = delta_date($date);
    
    my $delta_days = int($date_delta_ms->delta_minutes / (24*60));
    my $delta_days_rest = $date_delta_ms->delta_minutes % (24*60);
    my $delta_hours = int($delta_days_rest / 60);
    my $delta_hours_rest = $delta_days_rest % 60;
    
    my $return = sprintf('%02im:%02is',$delta_hours_rest,$date_delta_ms->seconds);
    
    if ($delta_hours) {
        $return = sprintf('%02ih:%s',$delta_hours,$return);
    }
    if ($delta_days) {
        $return = sprintf('%02id %s',$delta_days,$return);
    }
    
    return $return;
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
        
        return DateTime->new(
            (map { $_ => $+{$_} } qw(year month day hour minute second)),
            time_zone   => 'UTC',
        );
    }
    
    return;
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

Removes diacritic marks and uppercases a string for better compareability

=head3 parse_ship_type

 my $ship_type = parse_ship_type($human_type);

Converts a human ship name into the ship type

=head2 delta_date

 delta_date($date);

Returns a DateTime::Duration object

=head2 delta_date_format

 delta_date_format($date);

Returns a human readable delta for the given date

=head2 parse_date

Returns a DateTime object for the given timestamp from the api response

=cut