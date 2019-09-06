package THP::EnaStart;

use strict;
use warnings;
use Config::File qw(read_config_file);
use File::Basename;
use POSIX qw(strftime);
use LWP::Simple;
use THP::DB;
use List::MoreUtils qw(first_index);

use base ('Bio::EnsEMBL::Hive::Process');

=pod
this runnable uses a regex (which may need updating in the future): $analysis_title =~ /([ESD]RR[0-9]{6,7})/
=cut

sub param_defaults {

    return {
	'PIPERUN' => undef,
	'orgs' => [],
    };
}

sub fetch_input {

    my $self = shift @_;
    $self->_LoadConf(); 
    $self->{'datestring'} = strftime "%d_%b_%y", localtime;
    $self->{'col_submitted_file'} = $self->{config_hash}->{ENAGET}{expected_cols}{submitted_ftp}; 
    $self->{'col_submitted_md5'} = $self->{config_hash}->{ENAGET}{expected_cols}{submitted_md5};
    $self->{'col_last_updated'} = $self->{config_hash}->{ENAGET}{expected_cols}{last_updated}; #MySQL uses yyyy-mm-dd. report format is already in this format at time of writing
    $self->{'col_ERZ'} = $self->{config_hash}->{ENAGET}{expected_cols}{analysis_acc};
    $self->{'col_title'} = $self->{config_hash}->{ENAGET}{expected_cols}{analysis_title};
    $self->_dbconnect();
#    print $self->{'expected_cols'}->[2];
}

sub run {

    my $self = shift @_;
    my $downloadReportUrl = $self->{config_hash}->{ENAGET}{filereport};
    my $downloadReportFile = $self->{config_hash}->{storage}."/".$self->{config_hash}->{enastudy}."_crams_".$self->{datestring}.".txt";
    getstore($downloadReportUrl,$downloadReportFile); #download file report
    open(my $fh, "<", $downloadReportFile)
	or die "Can't open < $downloadReportFile : $!";
    my $header = <$fh>;
    chomp $header;
    my @cols=split("\t",$header);
    my $length = scalar @cols;
    my $counter = 0;
    my $skipped_counter = 0;
    my $before = $self->{plant_db}->select('select count(*) from CRAMS')->fetchrow_hashref()->{'count(*)'};
    while (my $row = <$fh>) {
	$counter++;
	my $level = 0; #level of submission. 0 means no cram file location, needs waiting or resubmission
	chomp $row;
	my @arr = split("\t",$row);
	die "can't find expected number of columns ($length) in line $counter (+1 if incl header) in $downloadReportFile\n" unless $length == scalar @arr;
	my $cram_file_col = first_index { $_ eq $self->{col_submitted_file} } @cols;
	die "looking for column '$self->{col_submitted_file}' ($downloadReportFile) but can't find it" unless $cram_file_col > -1;
	my @filecolsplit = split(";",$arr[$cram_file_col],2); #annoyingly the submitted_ftp col has 2 files (.cram and .md5)
	my $index_of_cram_file = first_index { /ftp\..+\.cram/ } @filecolsplit; #.cram and .md5 are in random order and the order should be reflected in column 'submitted_md5' too
	my $submitted_file;
	my $submitted_md5;
	#some historic bug makes it hard to extract run id from title the preffered way for some rows:
	#Alignment of (, ', S, R, R, 3, 3, 7, 1, 8, 7, 6, ', ,, ) to AGPv3
	#try to get from file name instead: $run_id_alt
	my $run_id_alt; 
	if ($index_of_cram_file > -1){
	    $level++; #upgrade submission status if cram file found
	    $submitted_file = $filecolsplit[$index_of_cram_file];
	    if ($submitted_file !~ m(^ftp://)){ #at time of writing the file report was missing out 'ftp://' so the urls were not resolveable
		$submitted_file = "ftp://".$submitted_file;
	    }
	    $run_id_alt = $1 if $submitted_file =~ m|([ESD]RR[0-9]{6,7}).cram$|;
	    my $md5_col = first_index { $_ eq $self->{col_submitted_md5} } @cols;
	    die "looking for column '$self->{col_submitted_md5}' ($downloadReportFile) but can't find it" unless $md5_col > -1;
	    my @md5colsplit = split(";",$arr[$md5_col],2);
	    if ($index_of_cram_file < scalar @md5colsplit ){ # avoid out of bounds error. 
		$submitted_md5 = $md5colsplit[$index_of_cram_file]; 
	    }else{
		warn "could not resolve md5/file location for line $counter (+1 incl header) in $downloadReportFile: columns submitted_ftp and submitted_md5 don't appear to have same number of elements\nnot adding this file to db\n";
		$skipped_counter++;
		next;
	    }
	}
	#get other cols (should put in sub routine to avoid code duplication ...) 
	my $othercols = first_index { $_ eq $self->{col_last_updated} } @cols;
	die "looking for column '$self->{col_last_updated}' ($downloadReportFile) but can't find it" unless $othercols > -1;
	my $submitted_date = $arr[$othercols];
	$othercols = first_index { $_ eq $self->{col_ERZ} } @cols;
	die "looking for column '$self->{col_ERZ}' ($downloadReportFile) but can't find it" unless $othercols > -1;
	my $analysis_acc = $arr[$othercols];
	$othercols = first_index { $_ eq $self->{col_title} } @cols;
	die "looking for column '$self->{col_title}' ($downloadReportFile) but can't find it" unless $othercols > -1;
	my $analysis_title = $arr[$othercols];
	
#	print "$index_of_cram_file: $submitted_file:  $submitted_md5\n";
#	print "$submitted_date\t$analysis_acc\t \n";
#	$analysis_title =~ /[ESD]RR[0-9]{6,7}/;
	my $run_id;
	if($analysis_title =~ /([ESD]RR[0-9]{6,7})/) {
	    $run_id = $1;
	} elsif ($run_id_alt) { 
	    $run_id = $run_id_alt;
	} else {
	    warn "can not obtain run id from column '$self->{'col_title'}' line $counter (+ 1 incl header) in $downloadReportFile\nrun_id will be null in database\n"; #FOR LOGGING
#	    $skipped_counter++; #allow null for run_id
#	    next;
	}
	my $piperun = $self->param('PIPERUN');
	$self->{plant_db}->add_cram($analysis_acc,$run_id,$analysis_title,$submitted_file,$submitted_md5,$submitted_date,$level,$self->param('PIPERUN'),0); #final 0 = no to 'finished' column
	
#	print "$analysis_acc\t$run_id\t$analysis_title\t$run_id\t$submitted_file\t$submitted_md5\t$submitted_date\t$level\t$piperun\n" if $run_id;
    }
    close($fh)	|| warn "close failed: $!";
    $counter -= $skipped_counter;
    print "added/overwrote $counter crams to CRAMS table, skipped $skipped_counter\n"; #FOR LOGGING
    print "before adding there were already $before in the database\n";
    print "consider removing $downloadReportFile if not needed\n" if ! $skipped_counter; #for later: remove in-code

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


sub _LoadConf {

    my $self = shift @_;
    my $dirname = dirname(__FILE__);
    my $config_file = "$dirname/config.pl";
    die "can't find config at $config_file \n" unless -e $config_file;
    $self->{'config_hash'} = read_config_file($config_file);
	
}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}


1;
