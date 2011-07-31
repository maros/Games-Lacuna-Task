package Games::Lacuna::Task::Role::Config;

use 5.010;
use Moose::Role;

use YAML::Any qw(LoadFile);
use Games::Lacuna::Task::Utils qw(name_to_class);

has 'config' => (
    is              => 'ro',
    isa             => 'HashRef',
    traits          => ['NoGetopt'],
    lazy_build      => 1,
);

sub _build_config {
    my ($self) = @_;
    
    # Get global config
    my $global_config = {};
    
    foreach my $file (qw(lacuna config default)) {
        my $global_config_file = Path::Class::File->new($self->database,$file.'.yml');
        if (-e $global_config_file) {
            $self->log('debug',"Loading config from %s",$global_config_file->stringify);
            $global_config = LoadFile($global_config_file->stringify);
            last;
        }
    }
    
    return $global_config;
}

sub task_config {
    my ($self,$task_name) = @_;
    
    my $task_class = name_to_class($task_name);
    my $config_task = $self->config->{$task_name} || $self->config->{lc($task_name)} || {};
    my $config_global = $self->config->{global} || {};
    my $config_final = {};
    foreach my $attribute ($task_class->meta->get_all_attributes) {
        my $attribute_name = $attribute->name;
        $config_final->{$attribute_name} = $config_task->{$attribute_name}
            if defined $config_task->{$attribute_name};
        $config_final->{$attribute_name} //= $config_global->{$attribute_name}
            if defined $config_global->{$attribute_name};
        $config_final->{$attribute_name} //= $self->$attribute_name
            if $self->can($attribute_name) && defined $self->$attribute_name;
    }
    return $config_final;
}



no Moose::Role;
1;