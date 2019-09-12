package THP::DB;

use strict;
use warnings;
use Config::File qw(read_config_file);
#use DBI;
#use Generator::Object;
use Bio::EnsEMBL::DBSQL::DBConnection;


sub new{

    my ($class, $db, $host, $port, $user, $pw) = @_;
    defined $db and $host and $port and $user and $pw
	or die "Some required parameters are missing in the constructor of the FillTable\n";
    my $self = {
	plant_db => $db,
	host => $host,
	port => $port,
	user => $user,
	pw => $pw,
    };
    bless $self,$class;
    $self->login;
    return $self;
}


sub login{
    
    my $self = shift;
    $self->{plant_dbh} = Bio::EnsEMBL::DBSQL::DBConnection->new(
	-user   => $self->{user},
	-pass   => $self->{pw},
	-dbname => $self->{plant_db},
	-host   => $self->{host},
	-port   => $self->{port}
	);
    $self->{'curs_arr'} = []; # to put the active cursors (sub select)
    $self->{plant_dbh}->reconnect_when_lost(1);
    $self->{plant_dbh}->disconnect_when_inactive(0);
    
}

sub logout{

    my $self = shift;
    foreach (@{$self->{curs_arr}}) #'finish' the cursors that have been created (for eg, sub select)
    {
	$_->finish();
    }
#    $self->{plant_dbh}->disconnect(); #only available directly from DBI, not when wrapped in Bio::EnsEMBL::DBSQL::DBConnection
    $self->{plant_dbh}->disconnect_when_inactive(1);
    $self->{plant_dbh}->reconnect_when_lost(0);
    print "no more db use ('$self->{plant_db}' at host: $self->{host}) finishing cursors\n";
}

sub fill_t_orgs{

    my ($self, $arref_all_species, $piperun) = @_;

    my $sth = $self->{plant_dbh}->prepare("select count(*) from ORGS");
    $sth->execute();
    my $orgs_before = $sth->fetchrow_hashref()->{'count(*)'};
    $sth->finish();
    my $count = 0;
    for my $href (@{ $arref_all_species }) {
	$self->{plant_dbh}->do("INSERT INTO ORGS VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE piperun = VALUES(piperun), finished = VALUES(finished)", undef, $href->{ORGANISM}, $href->{REFERENCE_ORGANISM}, $piperun, 0); #the '0' is for "not completed" (column 'finished' in table ORGS)  
	$count++;
    }
    return ($orgs_before, $count);
#    http://www.mysqltutorial.org/mysql-insert-or-update-on-duplicate-key-update/
}

sub add_cram{ #add one row at a time to table CRAMS. fill_t_orgs takes in-memory hash but crams are from a file that is read by the calling runnable

    my ($self, $analysis_acc,$run_id,$analysis_title,$submitted_file,$submitted_md5,$submitted_date,$level,$piperun,$finished,$uploaded,$submitted) = @_;
    $self->{plant_dbh}->do("REPLACE INTO CRAMS (analysis_id, run_id, title, filename, md5, date, file_exists, piperun,finished) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", undef, $analysis_acc,$run_id,$analysis_title,$submitted_file,$submitted_md5,$submitted_date,$level,$piperun,$finished);

}

sub add_aerun { #add one row at a time to table CRAMS. fill_t_orgs takes in-memory hash but crams are from a file that is read by the calling runnable
    
    my ($self,$ae_date,$ena_date,$biorep_id,$run_id,$cram_url,$sample_id,$study_id,$assembly,$org,$ref_org,$quality,$status,$md5_sum,$piperun,$finished,$uploaded,$submitted) = @_;

    $self->{plant_dbh}->do("REPLACE INTO AERUNS (ae_date,ena_date,biorep_id,run_id,cram_url,sample_id,study_id,assembly,org,ref_org,quality,status,md5_sum,piperun,finished,uploaded,submitted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",undef,$ae_date,$ena_date,$biorep_id,$run_id,$cram_url,$sample_id,$study_id,$assembly,$org,$ref_org,$quality,$status,$md5_sum,$piperun,$finished,$uploaded,$submitted);

}

sub add_enasub { #add new analysis id from a successful cram submission
    
    my ($self, $analysis_id, $run_id, $biorep_id, $submission_id, $piperun) = @_;
    $self->{plant_dbh}->do("INSERT INTO ENASUBS (analysis_id, run_id, biorep_id, submission_id, piperun) VALUES (?, ?, ?, ?, ?)", undef, $analysis_id, $run_id, $biorep_id, $submission_id, $piperun);

}

sub add_study { #add metadata for a study

    my ($self, $study_id, $prj_id, $alias, $title, $abstract, $description, $piperun, $has_samples, $has_dim, $written, $finished) = @_;
    $self->{plant_dbh}->do("REPLACE INTO STUDY (study_id, prj_id, alias, title, abstract, description, piperun, has_samples, has_dim, written, finished) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", undef, $study_id, $prj_id, $alias, $title, $abstract, $description, $piperun, $has_samples, $has_dim, $written, $finished);

}

sub add_sample { #add metadata for a sample

    my ($self, $samp_id, $primary_id, $alias, $center, $science, $title, $description, $piperun, $written) = @_;
    $self->{plant_dbh}->do("REPLACE INTO SAMPLE (sample_id, primary_id, alias, center, scientific_name, title, description, piperun, written) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", undef, $samp_id, $primary_id, $alias, $center, $science, $title, $description, $piperun, $written);

}

sub add_attribute { #add sample attributes (tag-value pairs within <SAMPLE_ATTRIBUTE> block in XML

    my ($self, $samp_id, $tag, $value, $piperun) = @_;
    $self->{plant_dbh}->do("REPLACE INTO ATTRIBUTES (sample_id, tag, value, piperun) VALUES (?, ?, ?, ?)", undef, $samp_id, $tag, $value, $piperun);

}

sub add_ensgenome {

   my ($self, $species_production_name, $assembly_accession, $assembly_name, $assembly_default, $url_name, $piperun) = @_;
   $self->{plant_dbh}->do("REPLACE INTO NAME_CHECK (species_production_name, assembly_accession, assembly_name, assembly_default, url_name, piperun) values (?, ?, ?, ?, ?, ?)", undef, $species_production_name, $assembly_accession, $assembly_name, $assembly_default, $url_name, $piperun);

}

sub select{

    my ($self, $query) = @_;
    my $sth = $self->{plant_dbh}->prepare($query) ||  die "Error preparing query:\n$query\n" . $self->{plant_dbh}->errstr . "\n";
    $sth->execute() ||  die "Error executing query:\n$query\n" . $sth->errstr . "\n";
    push @{$self->{curs_arr}}, $sth;  
    return $sth;
    #usage:
    #$sth->fetchrow_hashref()->{'count(*)'};
    #$sth->fetchrow_array();

}
 
1;

