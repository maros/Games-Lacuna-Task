package Games::Lacuna::Task::Report::BuildQueue;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;

use Moose::Role;

use Games::Lacuna::Task::Utils qw(parse_date format_date format_duration);

sub report_build_queue {
    my ($self) = @_;
    
    my $table = Games::Lacuna::Task::Table->new(
        headline=> 'Build Queue Report',
        columns => ['Planet','Size','Finished at','Finished in'],
    );
    
    foreach my $planet_id ($self->my_planets) {
        $self->_report_build_queue_body($planet_id,$table);
    }
    
    return $table;
}

sub _report_build_queue_body {
    my ($self,$planet_id,$table) = @_;
    
    my $planet_stats = $self->my_body_status($planet_id);
    my @buildings = $self->buildings_body($planet_stats);

    my $timestamp = time();
    my $building_count = 0;
    my $max_date_end = 0;
    
    foreach my $building_data (@buildings) {
        next
            unless (defined $building_data->{pending_build});
        my $date_end = parse_date($building_data->{pending_build}{end});
        next
            if $timestamp > $date_end;
        $building_count ++;
        $max_date_end = $date_end
            if $date_end > $max_date_end;
    }
    
    $table->add_row({
        planet          => $planet_stats->{name},
        size            => $building_count,
        finished_at     => ($max_date_end ? format_date($max_date_end) : 'now'),
        finished_in     => (format_duration($max_date_end) // '-'),
    });
}

no Moose::Role;
1;