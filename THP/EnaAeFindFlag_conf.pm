package THP::EnaAeFindFlag_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
#	'RERUN' => 1,
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [


	{  -logic_name => 'ena_start',
	   -module     => 'THP::EnaStart',
	   -flow_into  => {
                1 => [ 'species_start' ],  
            },
	},
        {   -logic_name => 'species_start',
            -module     => 'THP::SpeciesFact',
            -flow_into => {
                '2->A' => [ 'find_crams' ],   # will create a fan of jobs
		'A->1' => [ 'find_finished' ], 
		1      => [ 'find_finished' ], 
            },
        },
        {   -logic_name    => 'find_crams',
            -module        => 'THP::FindCrams',
            -analysis_capacity  =>  4,
        },
	{   -logic_name    => 'find_finished',
	    -module        => 'THP::FindFinished',
	},


    ];
}

1;

