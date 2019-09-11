package THP::GetStudyMet;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;

use HTTP::Tiny;
use XML::LibXML;

use base ('Bio::EnsEMBL::Hive::Process');


sub param_defaults {

    return {
	'CHOOSE_RUNS' => undef,
	'reload' => 0, #if study already in DB don't (0)/do (1) grab it again from ENA
    };
}

sub fetch_input {

    my $self = shift @_;
    my $id = $self->param_required('study_id');
    $self->{piperun} = $self->param_required('PIPERUN');
    $self->{reload} = $self->param('reload');
    $self->_LoadConf(); 
    $self->_dbconnect();
    my $view = $self->{config_hash}->{ENAGET}{view};
    $view =~ s/REPLACE/$id/;
    $self->{url} = $view;
    $self->{http} = HTTP::Tiny->new();

    if ($self->param('CHOOSE_RUNS') && @{$self->param('CHOOSE_RUNS')}){ 
	my $join = join "','", @{$self->param('CHOOSE_RUNS')};
	$self->{run_list} =  "('".$join."')";
	print "DETECTED RUNS: $self->{run_list}\n"; #REMOVE, TESTING ONLY
    }


}

sub run {

    my $self = shift @_;
    my $study_id = $self->param('study_id');
    if (! $self->{reload} ) {
	my $query_check = "select * from STUDY where study_id = '$study_id'";
	my $sth = $self->{plant_db}->select($query_check);
	warn "study $study_id already exists in STUDY table and with 'reload' off it won't be grabbed again from ENA API (but existing flags will be overwritten/reset)\n" if $sth->rows;
	my $query_reset = "update STUDY set piperun = $self->{piperun}, has_samples = 0, has_dim = 0, written = 0, finished = 0 where study_id = '$study_id'";
	$self->{plant_db}->select($query_reset);
	return if $sth->rows;
    }

    my $response = $self->{http}->get($self->{url});
    die "bad response on url $self->{url}\n$response->{reason}\n" unless $response->{success};
    my $xmlresp = $response->{content};
    my $dom = XML::LibXML->load_xml(string => $xmlresp); #XML::LibXML::DOM
    my $doc = $dom->documentElement; #root (XML::LibXML::Document I think, but inherents from XML::LibXML::Node so treated as such ...)
    my @check = $doc->findnodes( './STUDY' );
    die "could not get <STUDY> node from response from url $self->{url}" unless @check;
    my $alias = $doc->findvalue('./STUDY/@alias');
    my $prj_id = $doc->findvalue('./STUDY/IDENTIFIERS/SECONDARY_ID');
    my $title = $doc->findvalue('./STUDY/DESCRIPTOR/STUDY_TITLE');
    $title =~ s/\R/ /g;
    my $abstract = $doc->findvalue('./STUDY/DESCRIPTOR/STUDY_ABSTRACT');
    $abstract =~ s/\R/ /g;
    my $description = $doc->findvalue('./STUDY/DESCRIPTOR/STUDY_DESCRIPTION');
    $description =~ s/\R/ /g;
    $self->{plant_db}->add_study($study_id, $prj_id, $alias, $title, $abstract, $description, $self->param('PIPERUN'), 0, 0, 0, 0);

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
    my $piperun = $self->{piperun};
    my $study_id = $self->param('study_id');
    my $run_list = $self->{run_list};
    my $query = "select distinct sample_id from AERUNS where piperun = $piperun and study_id = '$study_id'";
    if ($run_list){
	$query = $query." and biorep_id in $run_list";
    }
#    print $query."\n";
    my $sth = $self->{plant_db}->select($query);
    while (my $row = $sth->fetchrow_hashref()){
	print $row->{sample_id}."\n";
	$self->dataflow_output_id( {
	    'samp_id'    => $row->{sample_id},
	    'reload'     => $self->{reload},
	    'PIPERUN'    => $piperun, 
				   }, 2);
    }
    $self->dataflow_output_id( {
	'PIPERUN'        => $piperun,
	'study_id'       => $study_id,
	'CHOOSE_RUNS'    => $self->param('CHOOSE_RUNS'),
			       }, 1);

}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}

1;
