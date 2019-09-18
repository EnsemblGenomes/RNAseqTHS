package THP::CramUpSubmit_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
	# Overide any defaults here
#	'FIND_FINISHED' => 1,
#	'LONGCHECK' => 0,
#	'ACTION' => 'VALIDATE'
    }
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'cramupsub',
            -module     => 'THP::CramUpFact',
            -flow_into => {
		1      => [ 'subfact' ],
                '2->A' => [ 'cramup' ], 
		'A->1' => [ 'subfact' ],
            },
        },
        {   -logic_name    => 'cramup',
            -module        => 'THP::CramUp',
            -analysis_capacity  =>  3,
        },
	{
	    -logic_name    => 'subfact',
	    -module        => 'THP::SubmitFact',
	    -flow_into  => {
		2  => [ 'subcram' ],
	    },
	},
	{
	    -logic_name    => 'subcram',
	    -module        => 'THP::SubCram',
            -analysis_capacity  =>  3,
	}
	
    ];
}


1;

