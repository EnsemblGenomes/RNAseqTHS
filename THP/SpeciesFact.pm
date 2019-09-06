package THP::SpeciesFact;

=pod
config stuff borrowed from here
https://alvinalexander.com/blog/post/perl/how-read-configuration-data-file-perl
installing stuff:
http://alumni.soe.ucsc.edu/~you/notes/perl-module-install.html
next config approach:
https://metacpan.org/pod/Config::File
=cut

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::JsonResponse;
use THP::DB;
use Generator::Object;


use base ('Bio::EnsEMBL::Hive::Process');

my $all_species_url;
my $config_hash;

sub param_defaults {

    return {
	'RERUN' => 0, # yes/1 = don't reset/grab species, re launch unfinished species
	'orgs' => [],
    };
}

sub fetch_input {

    my $self = shift @_;
    $self->param_required('PIPERUN');


}


sub run {

    my $self = shift @_;
    $self->_LoadConf(); #assign account details
    my $rerun = $self->param('RERUN');
    my $piperun = $self->param('PIPERUN');
    $self->{plant_db} = THP::DB->new(
	$self->{config_hash}->{DB}{name},
	$self->{config_hash}->{DB}{host},
	$self->{config_hash}->{DB}{port},
	$self->{config_hash}->{DB}{user},
	$self->{config_hash}->{DB}{pw}
	);
    if (!$rerun){ 
	print "1: grabbing species list from AE using $self->{all_species_url}\n"; #FOR LOGGING
	my $arref_all_species = THP::JsonResponse::get_Json_response($self->{all_species_url});
	my ($before, $after) = $self->{plant_db}->fill_t_orgs($arref_all_species, $piperun);
	print "$before species from previous piperun, now there are $after \n"; #FOR LOGGING
    } else {
	print "1: RERUN parameter is on. will not reset table ORGS\n";
    }

}

sub _LoadConf {

    my $self = shift @_;
    my $dirname = dirname(__FILE__);
    my $config_file = "$dirname/config.pl";
    die "can't find config at $config_file \n" unless -e $config_file;
    $self->{'config_hash'} = read_config_file($config_file);
    $self->{'all_species_url'} = $self->{config_hash}->{AEGET}{species};
	
}

sub write_output {
    
    my $self = shift;
    my $piperun = $self->param('PIPERUN');
    my $query_getorgs = "select reference_organism from ORGS where piperun = '$piperun'";
    if ($self->param('orgs') && @{$self->param('orgs')}){
	my $join = join "','", @{$self->param('orgs')};
	my $org_list =  "('".$join."')";
	$query_getorgs = $query_getorgs." and reference_organism in ".$org_list;
    }
    $query_getorgs = $query_getorgs." group by reference_organism";
    my $curs = $self->{plant_db}->select($query_getorgs);
    my $count = 0;
    while (my $ref = $curs->fetchrow_hashref()) {
	$count++;
	$self->dataflow_output_id( {
	    'organism'    => $ref->{'reference_organism'},
	    'PIPERUN' => $piperun
				   }, 2);
    }
    $self->dataflow_output_id( {
	'PIPERUN'    => $piperun,
	'orgs'       => $self->param('orgs')
			       }, 1);
}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}


1;
