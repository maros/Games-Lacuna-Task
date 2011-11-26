# ============================================================================
package Games::Lacuna::Task::ActionProto;
# ============================================================================

use 5.010;

use Moose;
extends qw(Games::Lacuna::Task::Base);
with qw(Games::Lacuna::Task::Role::Config);

use List::Util qw(max);
use Try::Tiny;
use Games::Lacuna::Task::Utils qw(name_to_class class_to_name);

sub run {
    my ($self) = @_;
    
    my $task_name = shift(@ARGV);
    my $task_class = name_to_class($task_name);
    
    if (! defined $task_name) {
        say "Missing command";
        $self->print_usage();
    } elsif ($task_name ~~ [qw(help ? --help -h -?)]) {
        $self->print_usage();
    } elsif (! ($task_class ~~ [$self->all_actions()])) {
        say "Unknown command '$task_name'";
        $self->print_usage();
    } else {
        $ARGV[0] = '--help'
            if defined $ARGV[0] && $ARGV[0] eq 'help';
        
        my $ok = 1;
        try {
            Class::MOP::load_class($task_class);
        } catch {
            $self->log('error',"Could not load task %s: %s",$task_name,$_);
            $ok = 0;
        };
        
        if ($ok) {
            my $configdir;
            my $opt_parser = Getopt::Long::Parser->new( config => [ qw( no_auto_help pass_through ) ] );
            $opt_parser->getoptions( "configdir=s" => \$configdir );
            
            $self->configdir($configdir)
                if defined $configdir && $configdir ne '';
            
            my $task_config = $self->task_config($task_name);
            
            my $pa = $task_class->process_argv($task_config);
            my $commandline_params = $pa->cli_params();
            
            $self->log('notice',("=" x $Games::Lacuna::Task::Constants::SCREEN_WIDTH));
            $self->log('notice',"Running task %s for empire %s",$task_name,$self->empire_name);
            
            my $object = $task_class->new(
                ARGV        => $pa->argv_copy,
                extra_argv  => $pa->extra_argv,
                ( $pa->usage ? ( usage => $pa->usage ) : () ),
                %{ $task_config }, # explicit params to ->new
                %{ $pa->cli_params }, # params from CLI
            );
            
            $object->execute;
            $self->log('notice',("=" x $Games::Lacuna::Task::Constants::SCREEN_WIDTH));
        }
    }
}

sub print_usage {
    my ($self) = @_;
    
    my $caller = Path::Class::File->new($0)->basename;
    
    my @commands;
    push(@commands,['help','Prints this usage information']);
    
    foreach my $class ($self->all_actions()) {
        my $command = class_to_name($class);
        Class::MOP::load_class($class);
        my $meta = $class->meta;
        my $description = $class->description;
        my $no_automatic = $meta->can('no_automatic') ? $meta->no_automatic : 0;
        $description .= " [Manual]"
            if $no_automatic;
        push(@commands,[$command,$description]);
    }
    
    my @attributes;
    my $meta = $self->meta;
    foreach my $attribute ($meta->get_all_attributes) {
        next
            if $attribute->does('NoGetopt');
        push(@attributes,['--'.$attribute->name,$attribute->documentation]);
    }
    
    my $global_options = _format_list(@attributes);
    my $available_commands = _format_list(@commands);
    
    say <<USAGE;
usage: 
    $caller command [long options...]
    $caller help
    $caller command  --help

global options:
$global_options

available commands:
$available_commands
USAGE
}

sub _format_list {
    my (@list) = @_;
    
    my $max_length = max(map { length($_->[0]) } @list);
    my $description_length = $Games::Lacuna::Task::Constants::SCREEN_WIDTH - $max_length - 7;
    my $prefix_length = $max_length + 5 + 1;
    my @return;
    
    foreach my $command (@list) {
        my $description = $command->[1];
        $description .= " [Manual]"
            if $command->[2];
        my @lines = _split_string($description_length,$description);
        push (@return,sprintf('    %-*s  %s',$max_length,$command->[0],shift(@lines)));
        while (my $line = shift (@lines)) {
            push(@return,' 'x $prefix_length.$line);
        }
    }
    return join("\n",@return);
}

sub _split_string {
    my ($maxlength, $string) = @_;
    
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