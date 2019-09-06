package THP::Test;

use strict;
use warnings;
use File::Basename;
use Config::File qw(read_config_file);
use THP::DB;
use base ('Bio::EnsEMBL::Hive::Process');

#example file: 

sub param_defaults {

    return {
        'organism' => undef, 
	'PIPERUN' => 1,
	'PERSTUDY' => 0,
    };
}

sub fetch_input {

    my $self = shift @_;
#    $self->param_required('organism');
    $self->_LoadConf(); 
    $self->_dbconnect();
#    $self->{biorep_id} = $self->{config_hash}->{AEGET}{expected_cols}{biorep_id};

}

sub run {

    my $self = shift @_;
    print "entered THP::Test\n";
    my $sth = $self->{plant_db}->select("select * from AERUNS limit 1");
    print "A column from AERUNS:\n";
    while (my @row = $sth->fetchrow_array) {  
	print join("\t", @row), "\n";
    }
    $self->{plant_db}->logout();

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
#    $self->{db}->logout();

}

1;
