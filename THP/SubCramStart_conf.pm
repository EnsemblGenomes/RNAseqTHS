package THP::SubCramStart_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
	# Overide any defaults here
#	'ACTION' => 'VALIDATE'
    }
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'cramsub_start',
            -module     => 'THP::SubmitFact',
            -flow_into => {
                2 => [ 'subcram' ],   # will create a fan of jobs
            },
        },
        {   -logic_name    => 'subcram',
            -module        => 'THP::SubCram',
            -analysis_capacity  =>  5,
        },
    ];
}


1;

