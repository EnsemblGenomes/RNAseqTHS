package THP::EnaStart_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

=pod
sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },

        'pipeline_name' => 'species_start',
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
    ];
}
=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'ena_start',
            -module     => 'THP::EnaStart',
#            -parameters => [ {
#                'PIPERUN'  => 2,
#            } ],
        },
    ];
}

1;

