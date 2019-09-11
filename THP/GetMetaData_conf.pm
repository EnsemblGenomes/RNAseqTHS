package THP::GetMetaData_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # Need to use as well as use base() to turn on INPUT_PLUS()

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},  # here we inherit anything from the base class
	#overide defaults
#	'reload' => 1,
#	'only_finished' => 1,
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'study_fan',
            -module     => 'THP::StudyMetaFact',
#            -parameters => { #choose one of three options (or add to input_id when seeding)
#                'orgs' => ['musa_acuminata','cyanidioschyzon_merolae','lupinus_angustifolius'],
#		'CHOOSE_STUDIES' => [],
#		'CHOOSE_RUNS' => [],
#	        'reload' => 0 
#            },
            -flow_into => {
                2 => [ 'study_start' ],
            },
        },
	{   -logic_name    => 'study_start',
	    -module        => 'THP::GetStudyMet',
	    -flow_into     => {
		'2->A'     => [ 'sample_met' ],
		'A->1'     => [ 'meta_done' ],
		1      => [ 'meta_done' ], 
	    },
	},
	{
	    -logic_name    => 'sample_met',
	    -module         => 'THP::GetSampMet', 
	},
	{
	    -logic_name    => 'meta_done',
	    -module        => 'THP::MetaDone',
	},
    ];
}

1;

