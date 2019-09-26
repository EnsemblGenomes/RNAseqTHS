package THP::Checks;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;
use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {

    return {
	'report_file'    => undef,
	'change_ass_name' => [],
	'check_ass_name' => 0,
    };
}

sub fetch_input {

    my $self = shift @_;
    $self->{piperun} = $self->param_required('PIPERUN');
    $self->{report_file} = $self->param('report_file');
    $self->{check_ass_name} = $self->param('check_ass_name');
    $self->{change_ass_name} = $self->param('change_ass_name');
    $self->_LoadConf(); 
    $self->_dbconnect();
    $self->{get_runs} = $self->{config_hash}->{AEGET}{runsXorg};
    $self->{get_ass} = $self->{config_hash}->{ENSGET}{genomes};
    $self->{rnaseq_ass} = $self->{config_hash}->{AEGET}{species};
    $self->{study}= $self->{config_hash}->{enastudy};

}

sub run {

    my $self = shift @_;
    my @check_arr = @{$self->{change_ass_name}};

    if ($self->{check_ass_name} && !@check_arr){
	$self->check_ass_names;
    }
    
    if (@check_arr){
	$self->change_names;
	return;
    }
    
    
    return unless $self->{report_file};
    open(my $fh, '>', $self->{report_file} ) or die "Could not open report file '$self->{report_file}' $!";

    print "\n\n----REPORT-----\n\n";
    print $fh "\n\n----REPORT-----\n\n";
    my $string;
    my $piperun = $self->{piperun};
    my $allruns = ($self->{plant_db}->select("select count(*) from AERUNS where piperun = '$piperun'")->fetchrow_array())[0];
    $string = "$allruns crams available at RNASeq-er (piperun $piperun)\n";
    print $string;
    print $fh $string;

    my $finished_runs = ($self->{plant_db}->select("select count(*) from AERUNS where piperun = '$piperun' and finished")->fetchrow_array())[0];
    $string = "$finished_runs of these crams are public in the ENA (study $self->{study}) (piperun $piperun)\n";
    print $string;
    print $fh $string;

    my $submitted_runs = ($self->{plant_db}->select("select count(*) from AERUNS where piperun = '$piperun' and submitted")->fetchrow_array())[0];
    $string = "$submitted_runs of these run are submitted to the ENA (study $self->{study}) and should be public soon (3-4 days from submission) (piperun $piperun)\n";
    print $string;
    print $fh $string;

    my $written_studies_curs = $self->{plant_db}->select("select ref_org,count(distinct study_id) from AERUNS where study_id in (select study_id from STUDY where written and piperun = $piperun) and piperun = $piperun group by ref_org  order by count(distinct study_id) desc");
    $string = "\n\nHere are the number of trackhubs written per reference organism (viewable in genome browser) (piperun $piperun)\n";
    print $string;
    print $fh $string;
    $string = "\n\nOrganism\tWritten trackhubs\n\n";
    print $string;
    print$fh $string;
    while (my @row = $written_studies_curs->fetchrow_array()){
	print $row[0]."\t".$row[1]."\n";
	print $fh $row[0]."\t".$row[1]."\n";
    }

    my $submitted_studies_curs = $self->{plant_db}->select("select ref_org,count(distinct study_id) from AERUNS where study_id in (select study_id from STUDY where finished and piperun = $piperun) and piperun = $piperun group by ref_org  order by count(distinct study_id) desc");
    $string = "\n\nHere are the number of trackhubs submitted per reference organism (searchable in the Track Hub Registry, and viewable in genome browser) (piperun $piperun)\n";
    print $string;
    print $fh $string;
    $string = "\n\nOrganism\tRegistered trackhubs\n\n";
    print $string;
    print$fh $string;
    while (my @row = $submitted_studies_curs->fetchrow_array()){
	print $row[0]."\t".$row[1]."\n";
	print $fh $row[0]."\t".$row[1]."\n";
    }


    my $written_crams_curs = $self->{plant_db}->select("select ref_org,count(*) from AERUNS where study_id in (select study_id from STUDY where written and piperun = $piperun) and piperun = $piperun group by ref_org  order by count(*) desc");
    $string = "\n\nHere are the number of inidividual cram files that have been made into tracks and written in to trackhubs. Per organism. (piperun $piperun)\n";
    print $string;
    print $fh $string;
    $string = "\n\nOrganism\tWritten tracks\n\n";
    print $string;
    print $fh $string;
    while (my @row = $written_crams_curs->fetchrow_array()){
	print $row[0]."\t".$row[1]."\n";
	print $fh $row[0]."\t".$row[1]."\n";
    }



    my $finished_crams_curs = $self->{plant_db}->select("select ref_org,count(*) from AERUNS where study_id in (select study_id from STUDY where finished and piperun = $piperun) and piperun = $piperun group by ref_org  order by count(*) desc");
    $string = "\n\nHere are the number of inidividual cram files that have been submitted to the Track Hub Registry as tracks as part of trackhubs. Per organism. (piperun $piperun)\n";
    print $string;
    print $fh $string;
    $string = "\n\nOrganism\tSubmitted tracks\n\n";
    print $string;
    print $fh $string;
    while (my @row = $finished_crams_curs->fetchrow_array()){
	print $row[0]."\t".$row[1]."\n";
	print $fh $row[0]."\t".$row[1]."\n";
    }


    print "\n\n----END REPORT-----\n\n";
    print $fh "\n\n----END REPORT-----\n\n";
    close $fh;

}

sub check_ass_names {

    my $self = shift @_;
    print "=====================\n";
    print "'check_ass_name' is set to 1/on ... \n";
    print "this check ignores the piperun parameter\n";
    my $name_query = "select distinct(assembly) from AERUNS where not exists (select 1 from NAME_CHECK where AERUNS.assembly = binary NAME_CHECK.assembly_default)";
    my $name_query_curs = $self->{plant_db}->select($name_query);
    if ($name_query_curs->rows) {
	print "------\n";
	while (my @row = $name_query_curs->fetchrow_array()){
	    print "assembly with name '".$row[0]."' is mentioned in RNASEQ-er but is not in Ensembl API\n";
	}
	print "------\n";
	print "Above assembly name discrepancies were found by comparing RNASEQ-er 'ASSEMBLY_USED' tag from here:\n$self->{get_runs}\n(add organism name to above API call).\n(Find organism names here: $self->{rnaseq_ass})\nwith\nEnsembl 'assembly_default' tag here\n$self->{get_ass}\n";
	print "If there is an alternative 'assembly_default' in Ensembl for any of these you can change them with this runnable, for example:\n";
	print "standaloneJob.pl THP::Checks -input_id '{ \"PIPERUN\" => $self->{piperun}, \"change_ass_name\" => [\"need_change_1\",\"alt_name_1\",\"need_change_2\",\"alt_name_2\"] }'\n";


    }else{
	print "\nNo assembly mismatches found\n";
        print "The comparison is between column 'assembly' in table AERUNS and column 'assembly_default' in NAME_CHECK table.\nAERUNS gets updated with THP::FindCrams jobs fanned from THP::SpeciesFact and NAME_CHECK gets updated in THP::TrackHubFact job ('fill_namecheck' => 1).\n";
	print "you can fill NAME_CHECK table with stand alone THP::TrackHubFact:\nstandaloneJob.pl THP::TrackHubFact -input_id '{ \"PIPERUN\" => $self->{piperun}, 'fill_namecheck' => 1 }'";
    }
    print "=====================\n";

}

sub change_names {

    my $self = shift @_;
    my @arr = @{$self->{change_ass_name}};

    my $left = 1;
    my $before;
    my $after;
    foreach (@arr){
	if ($left) {
	    $before = $_;
	    $left = 0;
	}else{
	    $after = $_;
	    $left = 1;
	    my $query = "update AERUNS set assembly = '$after' where assembly = '$before'";
	    print $query."\n";
	    my $rows = $self->{plant_db}->select($query)->rows;
	    print "$rows rows changed\n";
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


sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}

1;
