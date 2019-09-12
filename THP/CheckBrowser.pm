package THP::CheckBrowser;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;
use base ('Bio::EnsEMBL::Hive::Process');

#example file: 

sub param_defaults {

    return {
	'orgs'           => [],
	'CHOOSE_STUDIES' => [], 
	'CHOOSE_RUNS'    => [],
    };
}

sub fetch_input {

    my $self = shift @_;
    $self->{piperun} = $self->param_required('PIPERUN');
    $self->_LoadConf(); 
    $self->_dbconnect();
    $self->{ftp} = $self->{config_hash}->{THRACC}{ftp};
    if ($self->{config_hash}->{THRTEST}{on}){
	$self->{ftp} = $self->{config_hash}->{THRTEST}{ftp};
    }
#    $self->{biorep_id} = $self->{config_hash}->{AEGET}{expected_cols}{biorep_id};


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
	warn "no parameters ('orgs' or 'CHOOSE_STUDIES' or 'CHOOSE_RUNS') provided. Single THP::CheckBrowser will find all studies from all crams in table AERUNS in piperun $self->{piperun}";
    }

}

sub run {

    my $self = shift @_;
    my $orgs_list = $self->{orgs_list};
    my $study_list = $self->{study_list};
    my $run_list = $self->{run_list};

=pod
    print "entered THP::Test\n";
    my $sth = $self->{plant_db}->select("select * from AERUNS limit 1");
    print "A column from AERUNS:\n";
    while (my @row = $sth->fetchrow_array) {  
	print join("\t", @row), "\n";
    }
=cut
    my $ensembl = "http://plants.ensembl.org/TrackHub?url=";
    my $ftp = $self->{ftp};
    my $query = "select AERUNS.study_id, NAME_CHECK.url_name from AERUNS join STUDY on (AERUNS.study_id = STUDY.study_id) join NAME_CHECK on (AERUNS.ref_org = NAME_CHECK.species_production_name) where STUDY.written and STUDY.piperun = $self->{piperun}";


    if ($orgs_list && !$study_list and !$run_list){
	$query = $query." and AERUNS.ref_org in ".$orgs_list;
    }
    if ($study_list){
	$query = $query." and AERUNS.study_id in ".$study_list;
    }
    if ($run_list){
	$query = $query." and biorep_id in ".$run_list;
    }

    $query = $query." group by AERUNS.study_id, NAME_CHECK.url_name";
    print "\nquery generated: \n============\n".$query."\n============\n";

    my $sth = $self->{plant_db}->select($query);
    while (my $row = $sth->fetchrow_hashref()) {  
	my $study = $row->{study_id};
	my $org = $row->{url_name};
	print "-----url to load track hub ${study}-----\n";
	print $ensembl.$ftp."/${study}/"."hub.txt;species=".$org."\n";
	print "-------------------------------\n";
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
