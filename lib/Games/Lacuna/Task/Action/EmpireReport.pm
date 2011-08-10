package Games::Lacuna::Task::Action::EmpireReport;

use 5.010;

use Module::Pluggable 
    search_path => ['Games::Lacuna::Task::Report'],
    sub_name => 'all_reports';
    
use Moose;
extends qw(Games::Lacuna::Task::Action);
with 'Games::Lacuna::Task::Role::Notify',all_reports();

use Games::Lacuna::Task::Table;
use Games::Lacuna::Task::Utils qw(pretty_dump class_to_name);

has 'report' => (
    is              => 'rw',
    isa             => 'ArrayRef[Str]',
    documentation   => 'Specifies which sub-reports to include in the empire report',
    default         => sub { 
        [ map { class_to_name($_) } all_reports() ]
    },
);

sub description {
    return q[This task generates an informative empire status report];
}

sub run {
    my ($self) = @_;
    
    my $empire_name = $self->lookup_cache('config')->{name};

    my $report_html = join '',<DATA>;
    my @report_content;
    foreach my $report (@{$self->report}) {
        my $method = 'report_'.$report;
        push(@report_content,'<div>');
        foreach my $report_data ($self->$method()) {
            push(@report_content,$report_data);
        }
        push(@report_content,'</div>');
    }
    my $report_content = join("\n",@report_content);
    $report_html =~ s/\@REPORT\@/$report_content/g;

    warn $report_html;
    $self->notify(
        "[$empire_name] Status report",
        $report_html
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
    <title>Empire Report</title>
    <style type="text/css">
    th {
        border-bottom: 2px solid;
    }
    tr {
        border-bottom: 1px solid grey;
    }
    </style>
</head>
<body>
@REPORT@
</body>
</html>