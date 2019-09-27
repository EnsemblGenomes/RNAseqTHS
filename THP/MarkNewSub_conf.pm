package THP::MarkNewSub_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
	# Overide any defaults here
#	'ignore_pipe' => 0
    }
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'ena_start',
            -module     => 'THP::EnaStart',
            -flow_into => {
                1 => [ 'flag_finished' ], 
            },
        },
	{
	    -logic_name => 'flag_finished',
	    -module     => 'THP::FindFinished',
	},
    ];
}

1;

