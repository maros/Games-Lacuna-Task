package Games::Lacuna::Task::Role::Actions;

use 5.010;
use Moose::Role;

use Class::Load qw();

use Module::Pluggable 
    search_path => ['Games::Lacuna::Task::Action'],
    sub_name    => '_all_actions';

our @ALL_ACTIONS;

sub all_actions {
    my ($self) = @_;
    
    return @ALL_ACTIONS
        if scalar @ALL_ACTIONS;
    
    foreach my $action_class (_all_actions()) {
        my ($ok,$error) = Class::Load::try_load_class($action_class);
        
        unless ($ok) {
            $error =~ s/\n\n/\n/g;
            die "Could not load action class $action_class\n$error";
        } else {
            my $meta_action_class = $action_class->meta;
            
            next
                if $meta_action_class->can('deprecated')
                && $meta_action_class->deprecated;
            
            push(@ALL_ACTIONS,$action_class);
        }
    }
    
    return @ALL_ACTIONS;
}

1;