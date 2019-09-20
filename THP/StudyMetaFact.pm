package THP::StudyMetaFact;

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
	'reload' => 0, # sent down branch 2 to reload metadata from API (if '1')
	'only_finished' => 0,
    };
}

sub fetch_input {

    my $self = shift @_;
#    $self->{biorep_id} = $self->{config_hash}->{AEGET}{expected_cols}{biorep_id};
    my $piperun = $self->param_required('PIPERUN');
    $self->_LoadConf(); 
    $self->_dbconnect();
    $self->{'study_list'} = undef;
    $self->{'run_list'} = undef;
    $self->{'orgs_list'} = undef;
    $self->{'only_finished'} = $self->param('only_finished');
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
	warn "no parameters ('orgs' or 'CHOOSE_STUDIES' or 'CHOOSE_RUNS') provided. Single THP::StudyMetaFact will find studies from all crams in table AERUNS that are finished and in piperun $piperun";
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

    my $piperun = $self->param('PIPERUN');
    my $orgs_list = $self->{orgs_list};
    my $study_list = $self->{study_list};
    my $run_list = $self->{run_list};
    my $query_start = "select study_id, GROUP_CONCAT(biorep_id SEPARATOR ' ') as runs from AERUNS where piperun = $piperun"; 
    if ($self->{'only_finished'}) {
	$query_start = $query_start." and finished";
    }
    my $query_end = " group by study_id";
    if ($orgs_list && !$study_list and !$run_list){
	$query_start = $query_start." and ref_org in ".$orgs_list;
    }
    if ($study_list){
	$query_start = $query_start." and study_id in ".$study_list;
    }
    if ($run_list){
	$query_start = $query_start." and biorep_id in ".$run_list;
    }
    my $query = $query_start.$query_end;
    print $query."\n";
    my $sth = $self->{plant_db}->select($query);
    if ($run_list){
	while (my $row = $sth->fetchrow_hashref()){
	    my @runs = split(/ /, $row->{runs});
	    $self->dataflow_output_id( {
		'study_id'    => $row->{study_id},
		'CHOOSE_RUNS' => \@runs, #new run list, those from original list that belong to study
		'PIPERUN'     => $self->param('PIPERUN'),
		'reload'      => $self->param('reload'),
				       }, 2);
	}
    } else {
	while (my $row = $sth->fetchrow_hashref()){
	    print $row->{study_id}."\n";
	    $self->dataflow_output_id( {
		'study_id'    => $row->{study_id},
		'PIPERUN'     => $self->param('PIPERUN'), 
		'reload'      => $self->param('reload'),
				       }, 2);
	}
    }
    $self->dataflow_output_id( {
	'PIPERUN'        => $self->param('PIPERUN'),
	'CHOOSE_STUDIES' => $self->param('CHOOSE_STUDIES'),
	'CHOOSE_RUNS'    => $self->param('CHOOSE_RUNS'),
	'orgs'           => $self->param('orgs'),
	'only_finished'  => $self->param('only_finished'),
			       }, 1);
}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}

1;
