package THP::MetaDone;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;
use base ('Bio::EnsEMBL::Hive::Process');


sub param_defaults {

    return {
	'CHOOSE_RUNS' => undef,
    };
}

sub fetch_input {

    my $self = shift @_;
    $self->param_required('study_id');
    $self->_LoadConf(); 
    $self->_dbconnect();

}

sub run {

    my $self = shift @_;
    my $study_id = $self->param('study_id');
    my $query = "UPDATE STUDY SET has_samples = TRUE WHERE study_id = '$study_id'";
    if (!$self->param('CHOOSE_RUNS')) {
	$self->{plant_db}->select($query);
    }

}

sub _LoadConf {

    my $self = shift @_;
    my $dirname = dirname(__FILE__);
    my $config_file = "$dirname/config.pl";
    die "can't find config at $config_file \n" unless -e $config_file;
    $self->{'config_hash'} = read_config_file($config_file);
	
}

sub _dbconnect {

    my $self = shift @_;
    $self->{plant_db} = THP::DB->new(
	$self->{config_hash}->{DB}{name},
	$self->{config_hash}->{DB}{host},
	$self->{config_hash}->{DB}{port},
	$self->{config_hash}->{DB}{user},
	$self->{config_hash}->{DB}{pw}
	);
}


sub write_output {

    my $self = shift;
#    $self->dataflow_output_id( {
#	'organism'    => $self->param('organism'),
#	'PIPERUN'     => $self->param('PIPERUN')
#			       }, 1);

}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}

1;
