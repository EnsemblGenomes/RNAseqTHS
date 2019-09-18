package THP::SubCram;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;
use XML::Writer;
use IO::File;
use HTTP::Request::Common;
use LWP::UserAgent;
use XML::LibXML;


use base ('Bio::EnsEMBL::Hive::Process');


sub param_defaults {

    return {
	'ACTION' => 'ADD', #change to ADD after testing (from 'VALIDATE')
    };
}


sub fetch_input {

    my $self = shift @_;
    $self->param_required('organism'); #the reference organism
    $self->param_required('assembly'); #the specific assembly aligned to 
    $self->param_required('PIPERUN');
    $self->param_required('cram_url');
    $self->param_required('md5_sum');
    $self->param_required('biorep_id');
    $self->param_required('run_id');
    $self->param_required('sample_id');
    $self->param_required('study_id'); #submitter's study
    $self->_LoadConf(); 
    $self->{ourstudy} = $self->{config_hash}->{enastudy}; # our study (to hold all analysis/crams)
    $self->{user} = $self->{config_hash}->{ENAUSER}{name};
    $self->{pw} = $self->{config_hash}->{ENAUSER}{pw};
    $self->{center} = $self->{config_hash}{ENAUSER}{center};
    if ($self->{config_hash}->{ENAUSER}{test}){
	warn "config ENAUSER[test] is ON so successful ENA cram submissions will not persist\n";
	$self->{url} = $self->{config_hash}->{ENAUSER}{testurl};
    }else{
	$self->{url} = $self->{config_hash}->{ENAUSER}{posturl};
    } 
    $self->_dbconnect();

}

sub run {

    my $self = shift @_;
#   set up XML names and paths
    my $filename = fileparse($self->param('cram_url'));
    my $xml_name = $self->{config_hash}->{storage}."/$filename.xml";
    my $biorep = $self->param('biorep_id');
    my $out_xml = IO::File->new(">$xml_name");
    my $xml_writer = XML::Writer->new(OUTPUT => $out_xml, DATA_MODE => 1, DATA_INDENT => 2 );

#   make parameters local
    my $id = $self->param('run_id');
    $id = $self->param('biorep_id') unless $id;
    my $assembly = $self->param('assembly');
    my $umb = $self->{ourstudy};
    my $samp = $self->param('sample_id');
    my $run = $self->param('run_id');
    my $md5 = $self->param('md5_sum');


    #Write Analysis XML (https://ena-docs.readthedocs.io/en/latest/analyses/read-alignments.html)
    $xml_writer->xmlDecl('UTF-8');
    $xml_writer->startTag('ANALYSIS_SET');
#    $xml_writer->startTag('ANALYSIS', alias => "${id}_to_$assembly");
    if ($self->{center}) { #may not be needed. if not, remove from config
	$xml_writer->startTag('ANALYSIS', alias => "${id}_to_$assembly", center_name => $self->{center});
    } else {
	$xml_writer->startTag('ANALYSIS', alias => "${id}_to_$assembly");
    }

    $xml_writer->startTag('TITLE');
    $xml_writer->characters("Alignment of $id to $assembly");
    $xml_writer->endTag('TITLE');
    $xml_writer->startTag('DESCRIPTION');
    $xml_writer->characters("Integrated RNA-seq Analysis Pipeline (iRAP, http://doi.org/10.1101/002824) implemented on public data in the ENA (reads from run $id against assembly $assembly). For more information see: https://www.ebi.ac.uk/fg/rnaseq/api/. For other analysis of this type see https://www.ebi.ac.uk/ena/data/view/$umb");
    $xml_writer->endTag('DESCRIPTION');
    $xml_writer->emptyTag('STUDY_REF', accession => $umb);
    $xml_writer->emptyTag('SAMPLE_REF', accession => $samp);
    $xml_writer->emptyTag('RUN_REF', accession => $id);
    $xml_writer->startTag('ANALYSIS_TYPE');
    $xml_writer->emptyTag('REFERENCE_ALIGNMENT');
    $xml_writer->endTag('ANALYSIS_TYPE');
    $xml_writer->startTag('FILES');
    $xml_writer->emptyTag('FILE', filename => $filename, checksum => $md5, checksum_method => 'MD5', filetype => 'cram');
    $xml_writer->endTag('FILES');
    $xml_writer->endTag('ANALYSIS');
    $xml_writer->endTag('ANALYSIS_SET');
    $xml_writer->end();
    $out_xml->close;

    # Try submission: https://ena-docs.readthedocs.io/en/latest/general-guide/programmatic.html#submission-actions-without-submission-xml
    # print "SubCram entered for $biorep:\n$xml_name\n$sub_name\nid:$id\n"; #FOR TESTING
    my $action =  $self->param('ACTION');
    my $curl_equiv = "curl -u $self->{user}:$self->{pw} -F \"ACTION=$action\" -F \"ANALYSIS=\@$xml_name\" \"$self->{url}\""; #if there's an error this will help run the submission in isolation
    
    my $ua = LWP::UserAgent->new;
    my $req = POST($self->{url},
			'Content_Type' => 'form-data',
			'Content' => [
			    ANALYSIS     => [ $xml_name ],
			    ACTION       => $action,
			    center_name  => $self->{center},
			],
	);
    $req->authorization_basic($self->{user}, $self->{pw});
    my $response = $ua->request($req);
    die "failed to post analysis xml:\n".$response->status_line."\ncurl equivalent:\n$curl_equiv\n" unless $response->is_success;
    my $xmlresp = $response->content;
    my $dom = XML::LibXML->load_xml(string => $xmlresp); #XML::LibXML::DOM
    my $doc = $dom->documentElement; #root (XML::LibXML::Document I think, but inherents from XML::LibXML::Node so treated as such ...)
    my $success = $doc->findvalue( './@success' ); # string
    die "looking for value 'true' in attribute 'success' but did not find ('$success')\nresponse looks like this:\n".$doc->toString()."\ncurl equivalent:\n$curl_equiv\n" unless $success =~ /true/;
    my $anal_id = $doc->findvalue('./ANALYSIS/@accession'); #will be empty if 'ACTION' => 'VALIDATE'
    my $sub_id = $doc->findvalue('./SUBMISSION/@accession'); #will be empty if 'ACTION' => 'VALIDATE'
    if (!$anal_id && $action =~ /VALIDATE/){ 
	print "Submission done for $biorep, analysis id not found, but that's because 'ACTION' => 'VALIDATE'\n";
	print "no further action taken (no database logging)\n";
	unlink($xml_name);
	return;
    }
    if (!$anal_id){
	die "analysis id not found after submission of $filename ($biorep)\nresponse looks like this:\n".$doc->toString()."\ncurl equivalent:\n$curl_equiv\n";
    }
#    print $doc->toString()."\n"; #for debugging: check XML receipt
    print "submitted $biorep, analysis id = $anal_id\n"; #FOR LOGGING

    #Flag as submitted and add analysis id to database
    $self->{db}->add_enasub($anal_id,$self->param('run_id'),$self->param('biorep_id'),$sub_id, $self->param('PIPERUN'));
    my $query_flag = "UPDATE AERUNS set submitted = TRUE where biorep_id = '$biorep'";
    $self->{db}->select($query_flag);
    unlink($xml_name) or die "Can't delete $xml_name: $!\n";

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


}

sub post_cleanup {

    my $self = shift;
    $self->{db}->logout();

}

1;
