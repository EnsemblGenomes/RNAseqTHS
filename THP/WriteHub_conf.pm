package THP::WriteHub_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # Need to use as well as use base() to turn on INPUT_PLUS()

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
#        'fill_namecheck'  => 0,
#	'remove_old'      => 0,
#	'gca_hash'     => 0,
#	'reload' => 1,
#	'only_finished' => 1,

    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
	{
	    -logic_name   => 'hub_start', 
	    -module       => 'THP::TrackHubFact',
	    -flow_into    => {
		'2->A'    => [ 'hub_write' ],
		'A->1'    => [ 'hub_register' ],
		1         => [ 'hub_register' ],
	    },
	},
	{
	    -logic_name   => 'hub_write',
	    -module       => 'THP::TrackHubDir',
	},
	{
	    -logic_name   => 'hub_register',
	    -module       => 'THP::TrackHubReg',
	}
    ];
}

1;

