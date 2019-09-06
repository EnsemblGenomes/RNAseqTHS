package THP::FindFinished;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;
use base ('Bio::EnsEMBL::Hive::Process');

#example file: 

sub param_defaults {

    return {
	'PIPERUN' => undef,
	'orgs' => [],
	'ignore_pipe' => 1, # no need for 'PIPERUN' to limit finding finshed crams in AERUNS table
    };
}

sub fetch_input {

    my $self = shift @_;
    $self->_LoadConf(); 
    $self->_dbconnect();

}

sub run {

    my $self = shift @_;
    my $piperun = $self->param('PIPERUN');
    my $ignore_pipe = $self->param('ignore_pipe');
    
    my $query_alrdone = "update AERUNS set finished = TRUE where md5_sum in (select md5 from CRAMS where md5 is not null)";
    if ($piperun && !$ignore_pipe){
	$query_alrdone = $query_alrdone." and piperun = $piperun";
    }

    my $sth = $self->{plant_db}->select($query_alrdone);
    my $rows = $sth->rows;
    if ($piperun && !$ignore_pipe){
	print "$rows crams in piperun $piperun are already submitted (md5sum matched AERUNS vs CRAMS tables)\n"; #FOR LOGGING
    } else {
	print "$rows crams are already submitted (md5sum matched AERUNS vs CRAMS tables)\n"; #FOR LOGGING
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
    $self->dataflow_output_id( {
	'PIPERUN'     => $self->param('PIPERUN'),
	'orgs'        => $self->param('orgs')
			       }, 1);

}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}

1;
