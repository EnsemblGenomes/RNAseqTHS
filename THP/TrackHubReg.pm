package THP::TrackHubReg;


use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;
use THP::JsonResponse;
use JSON;
use HTTP::Request::Common;
use LWP::UserAgent;


use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {

    return {
	'gca_hash'     => 1, # grab and send GCA accessions to TH registry
	'orgs'           => [],
	'CHOOSE_STUDIES' => [], 
	'CHOOSE_RUNS'    => [],
	'only_finished' => 0,
	'delete_first'  => 0,
    };
}



sub fetch_input {

    my $self = shift @_;
    $self->_LoadConf();
    $self->_dbconnect();
    $self->{gca_hash} = $self->param('gca_hash');
    $self->{only_finished} = $self->param('only_finished');
    $self->{delete_first} = $self->param('delete_first');
    $self->{user} = $self->{config_hash}->{THRACC}{user};
    $self->{pw} = $self->{config_hash}->{THRACC}{pw};
    $self->{path} = $self->{config_hash}->{THRACC}{path};
    $self->{server} = $self->{config_hash}->{THRACC}{server};
    $self->{ftp} = $self->{config_hash}->{THRACC}{ftp};
    if ($self->{config_hash}->{THRTEST}{on}) {
	print "TEST ON\n";
	$self->{user} = $self->{config_hash}->{THRTEST}{user};
	$self->{pw} = $self->{config_hash}->{THRTEST}{pw};
	$self->{path} = $self->{config_hash}->{THRTEST}{path};
	$self->{server} = $self->{config_hash}->{THRTEST}{server};
	$self->{ftp} = $self->{config_hash}->{THRTEST}{ftp};

    }
    $self->{regout} = $self->{config_hash}->{registry_output};
    my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my ($sec,$min,$hour,$mday,$mon) = localtime();
    $self->{time_now} = "$mday$months[$mon]_$hour-$min-$sec";

    for my $defined ($self->{user}, $self->{pw}, $self->{path}, $self->{server}, $self->{ftp}){
	die "all THRACC and THRTEST fields (on, user, pw, path, server, ftp) need defining in config file. Detected some missing fields\n"
 unless $defined && $defined !~ /^ *$/;
    }


    $self->{piperun} = $self->param_required('PIPERUN');
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
	warn "no parameters ('orgs' or 'CHOOSE_STUDIES' or 'CHOOSE_RUNS') provided. Single THP::TrackHubReg will find all studies in STUDY that are written and in piperun $self->{piperun}";
    }



}

sub run {

    my $self = shift @_;

    my $orgs_list = $self->{orgs_list};
    my $study_list = $self->{study_list};
    my $run_list = $self->{run_list};
    my $query_getstudies = "select distinct AERUNS.study_id from AERUNS join STUDY using (study_id) where AERUNS.piperun = $self->{piperun} and STUDY.piperun = $self->{piperun} and not STUDY.finished and STUDY.written";
    if ($self->{only_finished}){
	$query_getstudies = $query_getstudies." and AERUNS.finished";
    }
    if ($orgs_list && !$study_list and !$run_list){
	$query_getstudies = $query_getstudies." and ref_org in ".$orgs_list;
    }
    if ($study_list){
	$query_getstudies = $query_getstudies." and AERUNS.study_id in ".$study_list;
    }
    if ($run_list){
	$query_getstudies = $query_getstudies." and biorep_id in ".$run_list;
    }
    
   
    my $sth = $self->{plant_db}->select($query_getstudies);
    my @login_args = ($self->{server}, $self->{user}, $self->{pw});
    my $auth_token = THP::JsonResponse::registry_login(@login_args); 
    my $report_file = $self->{regout}."/".$self->{time_now}.".txt";
    open(my $fh, '>', $report_file) or die "Could not open file '$report_file' for reporting:\n$!";
    while (my $row = $sth->fetchrow_hashref()){

	my $study = $row->{study_id};
	my $hub_url = $self->{ftp}."/".$study."/hub.txt";
	my $genomes_txt = $self->{path}."/".$study."/genomes.txt";

	if (! -e $genomes_txt){
	    warn "can not find (for parsing) genomes.txt file:\n$genomes_txt\nskipping registering $study\n";
	    print $fh "can not find (for parsing) genomes.txt file:\n$genomes_txt\nskipping registering $study\n";
	    next;
	}

	if ($self->{delete_first}) { 
	    my @del_args = ($self->{server}, $self->{user}, $auth_token, $study);
	    my ($success, $report) = THP::JsonResponse::delete_track(@del_args);
	    if ($success){
		print "removed tracks associated with $study\n"; #FOR LOGGING
	    } else {
		warn "problem removing tracks associated with $study (delete_first is on). Will go on to reregister without deleting first:\n$report\n";
		print $fh "problem removing tracks associated with $study (delete_first is on). Will go on to reregister without deleting first:\n$report\n";
	    }
#	    next;
	}

	my $gca_hash;
	if ($self->{gca_hash}){
	    $gca_hash = $self->_assembly_hash($genomes_txt,$fh);
	}

	my @register_args = ($self->{server}, $self->{user}, $hub_url, $auth_token, $gca_hash);
	my ($success, $report) = THP::JsonResponse::register_track(@register_args); 
	if ($success){
	    print "registered $hub_url\n"; #FOR LOGGING
	    my $query_finish = "update STUDY set finished = TRUE where study_id = '$study'";
	    $self->{plant_db}->select($query_finish);
	} else {
	    warn "problem registering $study. Will skip it.\n$report\n";
	    print $fh "problem registering $study. Will skip it.\n$report\n";
	}
    }
    close $fh;
    my @logout_args = ($self->{server}, $self->{user}, $auth_token);
    THP::JsonResponse::registry_logout(@logout_args);

}

sub _assembly_hash {
    
    my ($self, $genomes_txt,$exfh) = @_;
    my %genomes;
    open (my $fh, '<'.$genomes_txt) or die "Could not open file '$genomes_txt' $!";	    
    while (my $row = <$fh>) {
	chomp $row;
	my @cols = split / /, $row, 2;
	if ( $cols[0] && $cols[1]){
	    if ($cols[0] =~ /genome/){
		my $genome = $cols[1];
		my $query = "select assembly_accession from NAME_CHECK where assembly_default = '$genome'";
		my $sth = $self->{plant_db}->select($query);
		if (! $sth->rows){
		    warn "could not find assembly $genome in NAME_CHECK as parsed from genomes.txt file";
		    print $exfh "could not find assembly $genome in NAME_CHECK as parsed from genomes.txt file\n";
		    next;
		}
		my $gca = $sth->fetchrow_hashref()->{'assembly_accession'};
		$genomes{$genome} = $gca;
	    }
	}
    }
    close $fh;
    return \%genomes;
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
}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}


1;
