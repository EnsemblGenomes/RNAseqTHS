package THP::FindCrams;

use strict;
use warnings;
use Config::File qw(read_config_file);
use File::Basename;
use THP::JsonResponse;
use THP::DB;
use File::Basename;
use LWP::Simple;
#example (delete): https://www.ebi.ac.uk/fg/rnaseq/api/json/70/getRunsByOrganism/musa_acuminata

use base ('Bio::EnsEMBL::Hive::Process');

sub fetch_input {
    
    my $self = shift @_;
    $self->param_required('organism');
    $self->param_required('PIPERUN');
    $self->_LoadConf(); 
    $self->{'runsXorg'} = $self->{config_hash}->{AEGET}{runsXorg};
    $self->{biorep_id} = $self->{config_hash}->{AEGET}{expected_cols}{biorep_id};
    $self->{run_id} = $self->{config_hash}->{AEGET}{expected_cols}{run_id};
    $self->{cram_url} = $self->{config_hash}->{AEGET}{expected_cols}{cram_url};
    $self->{sample_id} = $self->{config_hash}->{AEGET}{expected_cols}{sample_id};
    $self->{study_id} = $self->{config_hash}->{AEGET}{expected_cols}{study_id};
    $self->{assembly} = $self->{config_hash}->{AEGET}{expected_cols}{assembly};
    $self->{org} = $self->{config_hash}->{AEGET}{expected_cols}{org};
    $self->{ref_org} = $self->{config_hash}->{AEGET}{expected_cols}{ref_org};
    $self->{ena_date} = $self->{config_hash}->{AEGET}{expected_cols}{ena_date};
    $self->{ae_date} = $self->{config_hash}->{AEGET}{expected_cols}{ae_date};
    $self->{quality} = $self->{config_hash}->{AEGET}{expected_cols}{quality};
    $self->{exp_quality} = $self->{config_hash}->{quality}; #needed because AE url filter doesn't always work (... /api/json/70/getRunsByOrga ...) 
    $self->{status} = $self->{config_hash}->{AEGET}{expected_cols}{status};
    $self->{skipped} = $self->{config_hash}->{skipped};
    $self->_dbconnect();

}

sub run {

    my $self = shift @_;
    my $org = $self->param('organism'); 
    my $url = $self->{runsXorg}.$org;
    my $arref_runs = THP::JsonResponse::get_Json_response($url);
    my %mon2num = qw(jan 01  feb 02  mar 03  apr 04  may 05  jun 06  jul 07  aug 08  sep 09  oct 10 nov 11 dec 12);
    my $counter = 0;
    my $before = $self->{plant_db}->select("select count(*) from AERUNS where ref_org = '$org'")->fetchrow_hashref()->{'count(*)'};
    for my $href (@{ $arref_runs }){
	$counter++;
	my $error_file = $self->{skipped}."/".$org."_cram_".$counter;
	my $ae_date = $href->{$self->{ae_date}};
	my $ena_date = $href->{$self->{ena_date}};
	my $biorep_id = $href->{$self->{biorep_id}};
	print "$counter : $biorep_id\n"; #testing, remove
	my $run_id = $href->{$self->{run_id}};
	my $cram_url = $href->{$self->{cram_url}};
	my $sample_id = $href->{$self->{sample_id}};
	my $study_id = $href->{$self->{study_id}};
	my $assembly = $href->{$self->{assembly}};
	my $org = $href->{$self->{org}};
	my $ref_org = $href->{$self->{ref_org}};
	my $quality = $href->{$self->{quality}};
	my $status = $href->{$self->{status}};
	my $md5_sum;

	my $all_defined = 1;
	for my $defined ($ae_date,$ena_date,$biorep_id,$run_id,$cram_url,$sample_id,$study_id,$assembly,$org,$ref_org,$quality,$status) {
	    if ( (! defined($defined)) or (! length $defined) ){
		$all_defined = 0;
	    }
	}
	
	if (! $all_defined) {
	    my $not_defined = "Could not get all expected fields from AE API for all elements: $url\nae_date:$ae_date\nena_date:$ena_date\nbiorep_id:$biorep_id\nrun_id:$run_id\ncram_url\n$cram_url\nsample_id:$sample_id\nstudy_id:$study_id\nassembly:$assembly\norg:$org\nref_org:$ref_org\nquality:$quality\nstatus:$status";
	    _write_error($error_file,$not_defined);
	    $counter--;
	    next;
	}

	for my $defined (ref($ae_date),ref($ena_date),ref($biorep_id),ref($run_id),ref($cram_url),ref($sample_id),ref($study_id),ref($assembly),ref($org),ref($ref_org),ref($quality),ref($status)) {
	    die "Expecting scalars in all elements (instead of arrays or hashes) of every hash here : $url.\tBut detected some references. Check config (AEGET[expected_cols]).\n" unless ! $defined;
	}

	if ($quality < $self->{exp_quality}) {
	    $counter--;
	    next;
	}

	my @date_list = split / /, $ae_date;
	die "date format of '$ae_date' different to what expected ($url)\n($biorep_id)\n" if scalar @date_list != 5;
	$ae_date = sprintf('%s-%s-%s',$date_list[3],$mon2num{lc $date_list[1]},$date_list[2]);
	@date_list = split / /, $ena_date;
	die "date format of '$ena_date' different to what expected ($url)\n($biorep_id)\n" if scalar @date_list != 5;
	$ena_date = sprintf('%s-%s-%s',$date_list[3],$mon2num{lc $date_list[1]},$date_list[2]);

	my $md5_file = $cram_url . ".md5";
#	md5 file should exist. very useful for tracking updates but this bit pushes up the run time dramatically. should ask AE if it can be included in the API result instead.
	my $remote_instance = get $md5_file;
	if (! $remote_instance){
	    my $no_md5 = "looking for md5 for a cram file but its md5 file does not seem to exist: $md5_file\n($biorep_id)";
	    _write_error($error_file,$no_md5);
	    $counter--;
	    next;
	}
	chomp $remote_instance;
	$md5_sum = (split / /,$remote_instance,2)[0];  
	$self->{plant_db}->add_aerun($ae_date,$ena_date,$biorep_id,$run_id,$cram_url,$sample_id,$study_id,$assembly,$org,$ref_org,$quality,$status,$md5_sum,$self->param('PIPERUN'),0,0,0); #final 0's = no to 'finished','uploaded','submitted' columns

#	last if $counter > 1; #for testing. REMOVE

    }
    print "Added/overwrote $counter AE bioreps for organism $org. $before of these bioreps were already there (may be updated though)\n"; #FOR LOGGING

}

sub _write_error {
    
    my ($filename, $message) = @_;
    warn $message;
    open(my $fh, '>', $filename) or die "Could not open file '$filename' when trying to warn about:\n$message\n$!";
    print $fh $message."\n";
    close $fh;

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
    $self->{plant_db}->logout();
    $self->dataflow_output_id( {
	'organism'    => $self->param('organism'),
	'PIPERUN'     => $self->param('PIPERUN')
			       }, 1);
}


1;
