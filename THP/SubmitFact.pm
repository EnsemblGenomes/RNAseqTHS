package THP::SubmitFact;

use strict;
use warnings;
use Config::File qw(read_config_file);
use File::Basename;
use THP::DB;

use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {

    return {
	'orgs' => [],
	'CHOOSE_STUDIES' => [], #add a study (if perstudy = 1) or do one study only (if perstudy = 0)
	'CHOOSE_RUNS' => [],
    };
}

sub fetch_input {

    my $self = shift @_;
#    $self->{biorep_id} = $self->{config_hash}->{AEGET}{expected_cols}{biorep_id};
    $self->param_required('PIPERUN');
    $self->_LoadConf(); 
    $self->_dbconnect();
    $self->{'study_list'} = undef;
    $self->{'run_list'} = undef;
    $self->{'orgs_list'} = undef;
    if ($self->param('CHOOSE_STUDIES') && @{$self->param('CHOOSE_STUDIES')}){ 
	my $join = join "','", @{$self->param('CHOOSE_STUDIES')};
	$self->{study_list} =  "('".$join."')";
    }
    if ($self->param('CHOOSE_RUNS') && @{$self->param('CHOOSE_RUNS')}){ 
	my $join = join "','", @{$self->param('CHOOSE_RUNS')};
	$self->{run_list} =  "('".$join."')";
	if ($self->{'study_list'}){
	    warn "'CHOOSE_RUNS' and 'CHOOSE_STUDIES' used. Can only use 1. Defaulting to study list";
	    $self->{run_list} = undef;
	}
    }
    if ($self->param('orgs') && @{$self->param('orgs')}){
	my $join = join "','", @{$self->param('orgs')};
	$self->{orgs_list} = "('".$join."')";
    }

    if ($self->{orgs_list} && ($self->{'study_list'} || $self->{'run_list'})){
	warn "organisms provided but so is a run/study list ('CHOOSE_STUDIES'/'CHOOSE_RUNS'). Organism list not necessary. These studies/runs will be picked regardless of organisms ('orgs' parameter ignored)";
    }
    if (!$self->{orgs_list} && !$self->{'study_list'} && !$self->{'run_list'}){
	warn "no parameters ('orgs' or 'CHOOSE_STUDIES' or 'CHOOSE_RUNS') provided. Single THP::CramUpFact will submit all crams in table AERUNS (should not be part of a fan)";
    }

}

sub run {

    my $self = shift @_;

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
    $self->{'db'} = THP::DB->new(
	$self->{config_hash}->{DB}{name},
	$self->{config_hash}->{DB}{host},
	$self->{config_hash}->{DB}{port},
	$self->{config_hash}->{DB}{user},
	$self->{config_hash}->{DB}{pw}
	);
}


sub write_output {

    my $self = shift;
    my $piperun = $self->param('PIPERUN');
    my $orgs_list = $self->{orgs_list};
    my $study_list = $self->{study_list};
    my $run_list = $self->{run_list};
    my $query = "select ref_org,assembly,cram_url,md5_sum,biorep_id,run_id,sample_id,study_id from AERUNS where piperun = $piperun and uploaded and not finished and not submitted"; 
    if ($orgs_list && !$study_list and !$run_list){
	$query = $query." and ref_org in ".$orgs_list;
    }
    if ($study_list){
	$query = $query." and study_id in ".$study_list;
    }
    if ($run_list){
	$query = $query." and biorep_id in ".$run_list;
    }
    my $sth = $self->{db}->select($query);
    while (my $cramref = $sth->fetchrow_hashref()){
#	print $cramref->{ref_org}."\t".$cramref->{assembly}."\t".$cramref->{cram_url}."\t".$cramref->{md5_sum}."\t".$cramref->{biorep_id}."\t".$cramref->{run_id}."\t".$cramref->{sample_id}."\t".$cramref->{study_id}."\n"; #for testing
	$self->dataflow_output_id( {
	    'organism'    => $cramref->{ref_org},
	    'assembly'    => $cramref->{assembly},
	    'PIPERUN'     => $self->param('PIPERUN'), 
	    'cram_url'    => $cramref->{cram_url},
	    'md5_sum'     => $cramref->{md5_sum},
	    'biorep_id'   => $cramref->{biorep_id},
	    'run_id'      => $cramref->{run_id},
	    'sample_id'   => $cramref->{sample_id},
	    'study_id'    => $cramref->{study_id},
				   }, 2);
    }
    $self->dataflow_output_id( {
	'PIPERUN'        => $self->param('PIPERUN'),
	'orgs'           => $self->param('orgs'),
	'CHOOSE_STUDIES' => $self->param('CHOOSE_STUDIES'),
	'CHOOSE_RUNS'    => $self->param('CHOOSE_RUNS'),
			       }, 1);
}

sub post_cleanup {

    my $self = shift;
    $self->{db}->logout();

}

1;
