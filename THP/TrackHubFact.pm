package THP::TrackHubFact;

use strict;
use warnings;
use Config::File qw(read_config_file);
use THP::DB;
use THP::JsonResponse;
use File::Basename;
use base ('Bio::EnsEMBL::Hive::Process');



sub param_defaults {

    return {
        'fill_namecheck' => 1,  
	'orgs' => [],
	'CHOOSE_STUDIES' => [],
	'CHOOSE_RUNS' => [],
	'only_finished' => 0,
    };
}


sub fetch_input {

    my $self = shift @_;
    $self->_LoadConf(); 
    $self->_dbconnect();
    $self->{piperun} = $self->param('PIPERUN');
    $self->{url_genomes} = $self->{config_hash}->{ENSGET}{genomes};
    $self->{namecheck} = $self->param('fill_namecheck');
    $self->{only_finished} = $self->param('only_finished');

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
	warn "no parameters ('orgs' or 'CHOOSE_STUDIES' or 'CHOOSE_RUNS') provided. Single THP::TrackHubFact will find studies from all crams in table AERUNS that are finished and in piperun $self->{piperun}";
    }

}

sub run {

    my $self = shift @_;

    if ($self->{namecheck}) {
	my $arref_genomes = THP::JsonResponse::get_Json_response($self->{url_genomes});
	HREF: for my $href (@{ $arref_genomes }){
	    my $species_production_name = $href->{name};
	    my $assembly_accession = $href->{assembly_accession};
	    my $assembly_name = $href->{assembly_name};
	    my $assembly_default = $href->{assembly_default};
	    my $url_name = $href->{url_name};
	    for my $defined ($species_production_name,$assembly_accession,$assembly_name,$assembly_default,$url_name) {
		warn "Could not get all expected fields (name,assembly_accession,assembly_name,assembly_default) for Ensembl genomes from $self->{url_genomes}\n" unless defined($defined) and length $defined;
	   	next HREF;
	     }
	    $self->{plant_db}->add_ensgenome($species_production_name, $assembly_accession, $assembly_name, $assembly_default, $url_name, $self->{piperun});
	}
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
    my $orgs_list = $self->{orgs_list};
    my $study_list = $self->{study_list};
    my $run_list = $self->{run_list};
    my $query = "select distinct AERUNS.study_id from AERUNS join STUDY using (study_id) where AERUNS.piperun = $self->{piperun} and STUDY.piperun = $self->{piperun} and not STUDY.finished";
    if ($self->{only_finished}) {
	$query = $query." and AERUNS.finished";
    }
    if ($orgs_list && !$study_list and !$run_list){
	$query = $query." and ref_org in ".$orgs_list;
    }
    if ($study_list){
	$query = $query." and AERUNS.study_id in ".$study_list;
    }
    if ($run_list){
	$query = $query." and biorep_id in ".$run_list;
    }
    my $sth = $self->{plant_db}->select($query);
    die "no studies found using query\n$query\n" unless $sth->rows; 
    while (my $row = $sth->fetchrow_hashref()){
	print $row->{study_id}."\n";
	$self->dataflow_output_id( {
	    'study_id'      => $row->{study_id},
	    'PIPERUN'       => $self->{piperun},
	    'only_finished' => $self->{only_finished},
				   }, 2);
    }

    $self->dataflow_output_id( {
	'PIPERUN'     => $self->{piperun},
	'orgs' => $self->param('orgs'),
	'CHOOSE_STUDIES' => $self->param('CHOOSE_STUDIES'),
	'CHOOSE_RUNS' => $self->param('CHOOSE_RUNS'),
			       }, 1);

}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}

1;
