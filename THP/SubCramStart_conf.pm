package THP::SubCramStart_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'cramup_start',
            -module     => 'THP::SubmitFact',
#            -input_ids => [ { #self seeding
#                'orgs' => ['musa_acuminata'],
#                'PIPERUN'  => 1,
#	       	'CHOOSE_RUNS' => ['ERR1512546','ERR1512544'],
#            } ],
            -flow_into => {
                2 => [ 'subcram' ],   # will create a fan of jobs
            },
        },
        {   -logic_name    => 'subcram',
            -module        => 'THP::SubCram',
            -analysis_capacity  =>  3,
        },
    ];
}


1;

