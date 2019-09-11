package THP::GetSampMet;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;

use HTTP::Tiny;
use XML::LibXML;

use base ('Bio::EnsEMBL::Hive::Process');


#example file: 

sub param_defaults {

    return {
	'reload' => 0,
    };
}


sub fetch_input {

    my $self = shift @_;
    $self->{id} = $self->param_required('samp_id');
    $self->{piperun} = $self->param_required('PIPERUN');
    $self->{reload} = $self->param('reload');
    $self->_LoadConf(); 
    $self->_dbconnect();
    my $view = $self->{config_hash}->{ENAGET}{view};
    $view =~ s/REPLACE/$self->{id}/;
    $self->{url} = $view;
    $self->{http} = HTTP::Tiny->new();
    $self->{att_ignore} = $self->{config_hash}->{ENAGET}{att_ignore};

}

sub run {

    my $self = shift @_;
    my $samp_id = $self->{id};

    if (! $self->{reload} ) {
	my $query_check = "select * from SAMPLE where sample_id = '$samp_id'";
	my $sth = $self->{plant_db}->select($query_check);
	warn "sample $samp_id already exists in SAMPLE table and with 'reload' off it won't be grabbed again from ENA API (but existing flags will be overwritten/reset)\n" if $sth->rows;
	my $query_reset = "update SAMPLE set piperun = $self->{piperun}, written = 0 where sample_id = '$samp_id'";
	my $query_resatt = "update ATTRIBUTES set piperun = $self->{piperun} where sample_id = '$samp_id'";
	$self->{plant_db}->select($query_reset);
	$self->{plant_db}->select($query_resatt);
	return if $sth->rows;
    }

    my $response = $self->{http}->get($self->{url});
    die "bad response on url $self->{url}\n$response->{reason}\n" unless $response->{success};
    my $xmlresp = $response->{content};
    my $dom = XML::LibXML->load_xml(string => $xmlresp); #XML::LibXML::DOM
    my $doc = $dom->documentElement; #root (XML::LibXML::Document I think, but inherents from XML::LibXML::Node so treated as such ...)
    my @check = $doc->findnodes( './SAMPLE' );
    die "could not get <SAMPLE> node from response from url $self->{url}" unless @check;
    my $alias = $doc->findvalue('./SAMPLE/@alias');
    my $center = $doc->findvalue('./SAMPLE/@center_name');
    my $primary_id = $doc->findvalue('./SAMPLE/IDENTIFIERS/PRIMARY_ID');
    my $title = $doc->findvalue('./SAMPLE/TITLE');
    $title =~ s/\R/ /g;
    my $description = $doc->findvalue('./SAMPLE/DESCRIPTION');
    $description =~ s/\R/ /g;
    my $science = $doc->findvalue('./SAMPLE/SAMPLE_NAME/SCIENTIFIC_NAME');
    $self->{plant_db}->add_sample($samp_id, $primary_id, $alias, $center, $science, $title, $description, $self->param('PIPERUN'), 0);

    my @attributes = $doc->findnodes( '//SAMPLE_ATTRIBUTE' );
    foreach(@attributes){
	my $tag = $_->findvalue('./TAG');
	if (index($self->{att_ignore}, $tag) != -1) { #ignore some default ENA annotations
	    next;
	}
	my $val = $_->findvalue('./VALUE');
	$self->{plant_db}->add_attribute($samp_id, $tag, $val, $self->param('PIPERUN'));
    }
	print "GOT and ADDED\n";

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
