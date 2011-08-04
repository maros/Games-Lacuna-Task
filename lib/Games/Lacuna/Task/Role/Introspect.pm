package Games::Lacuna::Task::Role::Introspect;

use 5.010;
use Moose::Role;

use Games::Lacuna::Task::Utils qw(class_to_name);

sub inspect {
    my ($self,$task_class) = @_;
    
    my $task_name = class_to_name($task_class);
    my $task_meta = $task_class->meta;
    
    $self->log('info',$task_class->description);
    
    my @attributes;
    foreach my $attribute ($task_meta->get_all_attributes) {
        next
            if $attribute->does('NoIntrospection');
        next
            if $attribute->does('NoGetopt');
        push (@attributes,$attribute);
    }
    if (scalar @attributes) {
        $self->log('info','Configuration:',$task_name);
        foreach my $attribute (@attributes) {
            $self->log('info',"- %s",$attribute->name);
            if ($attribute->has_documentation) {
                $self->log('info',"  Desctiption: %s",$attribute->documentation);
            }
            if ($attribute->is_required) {
                $self->log('info',"  Is required");
            }
            if ($attribute->has_type_constraint) {
                $self->log('info',"  Type: %s",$attribute->type_constraint->name);
            }
            if ($attribute->has_default) {
                my $default = $attribute->default;
                $default = $default->()
                    if (ref($default) eq 'CODE');
                $self->log('info',"  Default: %s",$default);
            }
            my $current_config = $self->task_config($task_name);
            if (exists $current_config->{$attribute->name}) {
                $self->log('info',"  Current configtation: %s",$current_config->{$attribute->name});
            }
        }
    } else {
        $self->log('info','Task %s does not take any options',$task_name);
    }
}

no Moose::Role;
1;
