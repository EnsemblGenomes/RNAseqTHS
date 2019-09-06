package THP::CramUp;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;
use LWP::Simple;
use Net::FTP;
use Digest::MD5;


use base ('Bio::EnsEMBL::Hive::Process');


sub param_defaults {

    return {
        'LONGCHECK' => 1,   # can check md5sum after download from AE, then upload to ENA, then re-download, and check again. takes ages but you know you are getting the integral file onto ENA servers
    };
}


sub fetch_input {

    my $self = shift @_;
    $self->param_required('cram_url');
    $self->param_required('md5_sum');
    $self->param_required('biorep_id');
    $self->_LoadConf(); 
    $self->_dbconnect();
    $self->{'start_time'} = time();

}

sub calc_md5{

    my $filename = shift;
    my $expected_md5 = shift;
    open (my $fh, '<', $filename);
    binmode ($fh); #don't think it is necessary but anyway
    my $actual_md5 = Digest::MD5->new->addfile($fh)->hexdigest;
    if ($actual_md5 eq $expected_md5){
	return 1;
    }else{
	return 0;
    }

}

sub run {

    my $self = shift @_;
    my $biorep_id = $self->param('biorep_id');
    my $cram_url = $self->param('cram_url');
    my $cram_base = basename($cram_url);
    my $cram_loc = $self->{config_hash}->{storage}."/".$cram_base;
    my $md5_sum = $self->param('md5_sum');
    my $host = $self->{config_hash}->{ENAUSER}{ftphost};
    my $user = $self->{config_hash}->{ENAUSER}{name};
    my $pw = $self->{config_hash}->{ENAUSER}{pw};
#*****TEST block (remove)****
#    print "\nentered CramUp with $biorep_id\t$cram_url\t$md5_sum\n";
#    return;
#****************************

    #ONE: Get from Array Express
    my $rc = getstore($cram_url, $cram_loc);
    if (is_error($rc)) {
	die "getstore of <$cram_url> failed with HTTP response code $rc\n";
    }

    if ($self->param('LONGCHECK')) {
	die "md5sum mismatch at local download stage:\n$cram_url\n$cram_loc\nExpected:\t$md5_sum\n" unless calc_md5($cram_loc,$md5_sum);
    }

    my $ftp = Net::FTP->new($host) or die "Cannot connect to $host: $@";
    $ftp->login($user, $pw) or die "Cannot login ", $ftp->message;
    $ftp->binary();
    #TWO: transfer to ENA ftp account
    $ftp->put($cram_loc) or die "problem ftp'ing file $cram_url ($cram_loc) ", $ftp->message;

    if (!$self->param('LONGCHECK')) {
	$ftp->quit;
	return;
    }

    my $well_travelled = $cram_loc.'_donald';
    #THREE: get back from ENA ftp account to check integrity
    $ftp->get($cram_base,$well_travelled) or die "problem getting $cram_base BACK from ENA server (to check md5 is still the same).\nOriginal URL: $cram_url\nLocal location: $cram_loc \n", $ftp->message;
    $ftp->quit;
    die "md5sum mismatch at RE-download stage:\nOriginal: $cram_url\nLocal: $cram_loc\nRE-downloaded: $well_travelled\nExpected:\t$md5_sum\n" unless calc_md5($well_travelled,$md5_sum);

    #FOUR: add flag to table delete $cram_loc and $well_travelled;
    my $query_upload_done = "update AERUNS set uploaded = TRUE where biorep_id = '$biorep_id'";
    my $sth = $self->{plant_db}->select($query_upload_done);
    my $row_altered = $sth->rows;
    if ($row_altered != 1) {
	warn "expected this query to alter 1 row but it doesn't seem to have done:\n$query_upload_done\nrows altered: $row_altered\n"; 
    }
    unlink($cram_loc);
    unlink($well_travelled);

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
    my $time_before = $self->{start_time};
    my $time_after = time();
    my $time_took = $time_after-$time_before;
    print "JOB took $time_took seconds.\n"; #FOR LOGGING
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
