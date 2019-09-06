package THP::CramUpStart_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
	# Overide defaults
#	'FIND_FINISHED' => 1,
#	'LONGCHECK' => 0,
    }
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'cramup_start',
            -module     => 'THP::CramUpFact',
            -flow_into => {
                2 => [ 'cramup' ], 
            },
        },
        {   -logic_name    => 'cramup',
            -module        => 'THP::CramUp',
            -analysis_capacity  =>  3,
        },
    ];
}


1;

