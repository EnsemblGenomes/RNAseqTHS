package THP::TrackHubDir;

use strict;
use warnings;
use File::Basename;
use File::Path;
use Config::File qw(read_config_file);
use THP::DB;
use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {

    return {
	'remove_old' => 1,
	'only_finished' => 0,
    };
}


sub fetch_input {

    my $self = shift @_;
    $self->_LoadConf(); 
    $self->{study_id} = $self->param_required('study_id');
    $self->{piperun} = $self->param_required('PIPERUN');
    $self->{remove_old} = $self->param('remove_old');
    $self->{only_finished} = $self->param('only_finished');
    $self->{dir_path} = $self->{config_hash}->{THRACC}{path};
    if ($self->{config_hash}->{THRTEST}{on}) {
	$self->{dir_path} = $self->{config_hash}->{THRTEST}{path};
    }
    $self->_dbconnect();
    $self->{new} = 1;
    $self->{dir} = $self->{dir_path}."/".$self->{study_id};
    if ( -d $self->{dir} ) {
	$self->{new} = 0; #directory already exists
    }
    $self->{hub_txt} = $self->{dir}."/hub.txt";
    $self->{genomes_txt} = $self->{dir}."/genomes.txt";
    $self->{ena_view} = $self->{config_hash}->{ENAVIEW}; 
    $self->{email} = $self->{config_hash}->{EMAIL};
    $self->{ae_link} = $self->{config_hash}->{AEGET}{runsXstudy}.$self->{study_id};
    $self->{seqer} = $self->{config_hash}->{AEGET}{seqer};
    umask oct($self->{config_hash}->{UMASK}); #permissions on new files and dirs will have config.UMASK restrictions
    $self->{genomes} = {};
    $self->{metatags} = $self->{config_hash}->{metatags};
}

sub run {

    my $self = shift @_;
    my $query_getstudy = "select * from STUDY where study_id = '$self->{study_id}' and piperun = '$self->{piperun}'";
    $self->{study_row} = $self->{plant_db}->select($query_getstudy)->fetchrow_hashref();
    die "can't find study $self->{study_id} in table STUDY for piperun $self->{piperun}\n" unless $self->{study_row};
    my $query_checkruns = "select * from AERUNS where study_id = '$self->{study_id}' and piperun = '$self->{piperun}'";
    my $finished = "";
    if ($self->{only_finished}) {
	$finished = "finished";
	$query_checkruns = $query_checkruns." and finished";
    }
    die "no $finished runs found in AERUNS for study $self->{study_id} and piperun $self->{piperun}\n" unless $self->{plant_db}->select($query_checkruns)->rows;
    if ($self->{new}){
	die "Unable to create directory: $self->{dir}\n" unless mkdir($self->{dir});
    }
    chmod 0777, $self->{dir};
    $self->make_hub_txt;
    if (! $self->{new}){
	if (open my $fh, '<'.$self->{genomes_txt}) { #if study not new read existing genomes.txt
	    while (my $row = <$fh>) {
		chomp $row;
		my @cols = split / /, $row, 2;
		if ( $cols[0] && $cols[1]){
		    $self->{genomes}->{$cols[1]} = 0 if ($cols[0] =~ /genome/); # 0 will stop it being processed later (if different from latest)
		}
	    }
	    close $fh;
	}
    }
    my $query_getgenomes = "select assembly from AERUNS where study_id = '$self->{study_id}' and piperun = '$self->{piperun}' group by assembly";
    my $sth = $self->{plant_db}->select($query_getgenomes);
    while (my $row = $sth->fetchrow_hashref) { #make list of current assemblies
	my $ass = $row->{assembly};
	die "can't get assembly for one of the rows in query\n[$query_getgenomes]\n" unless $ass;
	my $query_checkname = "select * from NAME_CHECK where assembly_default = '$ass'";
	my $check = $self->{plant_db}->select($query_checkname)->rows();
	die "assembly $ass used in $self->{study_id} doesn't appear in CHECK_NAME table\n" unless $check;
	$self->{genomes}->{$ass} = 1;
    }

    while ( my ($assembly, $current) = each($self->{genomes}) ) {
	my $ass_dir = $self->{dir}."/$assembly";
	if ($current){
	    if ( ! -d $ass_dir) {
		die "Unable to create directory ($!): $ass_dir\n" unless mkdir($ass_dir);
	    }
	    $self->make_trackDb_txt($assembly, $ass_dir);
	} elsif ( $self->{remove_old} ) { # if we are removing old assembly still don't if they are in NAME_CHECK
	    my $query_checkname = "select * from NAME_CHECK where assembly_default = '$assembly'";
	    my $check = $self->{plant_db}->select($query_checkname)->rows();
	    if ($check){  
		print "parameter 'remove_old' is on ($assembly) but this assembly is still available in Ensembl browser\n"; #FOR LOGGING
		$self->{genomes}->{$assembly} = 1; #turn it to current so it is included in genomes.txt
	    } else { #old assembly not in ensembl genomes anymore (not in NAME_CHECK)
		print "assembly $assembly appear to be old so it is being removed from $self->{study_id} track hub\n";
		rmtree $ass_dir if -d $ass_dir; 
	    } 
	}
    }

#    print Dumper($self->{genomes});
    $self->make_genomes_txt;
    my $query_written = "update STUDY set written = TRUE where study_id = '$self->{study_id}'";
    $self->{plant_db}->select($query_written);

}

sub make_hub_txt {

    my $self = shift @_;
    die "\nUnable to open file ($!) $self->{hub_txt}\n" unless(open FILE, '>'.$self->{hub_txt});
#    my $name = "<a href=\"$self->{seqer}\">RNASeq-er</a> alignment hub for ENA runs in $self->{study_id}";
    my $name = "RNASeq-er alignment hub for ENA runs in $self->{study_id}";
    my $href = "<a href=\"$self->{ena_view}$self->{study_id}\">$self->{study_id}</a>";
    my $genomesfile = fileparse($self->{genomes_txt});
    print FILE "hub $self->{study_id}\n";
    print FILE "shortLabel $name\n";
    if ($self->{study_row}->{title}) {
	print FILE "longLabel $self->{study_row}->{title}; $href\n";
    } else {
	print FILE "longLabel $name; $href\n";
    }
    print FILE "genomesFile $genomesfile\n";
    print FILE "email $self->{email}\n";
    print FILE "descriptionUrl $self->{ae_link}\n";
    close FILE;
    chmod 0666, $self->{hub_txt}; #config.UMASK = 0000 doesn't work on files created with open() and UMASK = 0111 doesn't allow files to be added into newly formed directories. 

}

sub make_genomes_txt {

    my $self = shift @_;
    die "\nUnable to open file ($!) $self->{genomes_txt}\n" unless(open my $fh, '>'.$self->{genomes_txt});
    for my $key ( keys $self->{genomes} ) {
	if ( $self->{remove_old} && ! $self->{genomes}->{$key}){
	    next;
	}
	print $fh "genome $key\n";
	print $fh "trackDb $key/trackDb.txt\n\n";
    }
    close $fh;
    chmod 0666, $self->{genomes_txt};
}

sub make_trackDb_txt {

    my ($self, $assembly, $ass_dir) = @_;
    my %sample_run;
    my $query_samplerun_a = "select sample_id,biorep_id from AERUNS where study_id = '$self->{study_id}' and assembly = '$assembly' and piperun = $self->{piperun}";
    my $query_samplerun_b = " group by sample_id, biorep_id";
    if ($self->{only_finished}){
	$query_samplerun_a = $query_samplerun_a." and finished";
    }
    my $query_samplerun = $query_samplerun_a.$query_samplerun_b;

    my $trackDb_txt = $ass_dir."/trackDb.txt";
    my $sth = $self->{plant_db}->select($query_samplerun);
    if (! $sth->rows ) {
	warn "no rows found for below query. Will not create/overwrite $trackDb_txt as this may exist from a separate piperun\n$query_samplerun\n";
	return;
    }
    die "\nUnable to open file ($!) $trackDb_txt\n" unless(open my $fh, '>'.$trackDb_txt);
    while (my $row = $sth->fetchrow_hashref) {  #for each sample (parent track)(key), store array of bioreps (child tracks) 
	if (! exists($sample_run{$row->{sample_id}}))
	{
	    $sample_run{$row->{sample_id}} = [$row->{biorep_id}];
	} else {
	    push $sample_run{$row->{sample_id}}, $row->{biorep_id};
	}
    }
#    my @metatags = split(' ', $self->{metatags});
    my @metatags = split('%', $self->{metatags});
    my @dim = qw/X Y A B C D E F G H I J K L M N O P Q R S T U V W/;
    if ( (scalar @metatags) >  (scalar @dim) ){
	@metatags = @metatags[0..((scalar @dim) - 1)];
    }
    my %dimensions;
    foreach my $tag ( @metatags ) {
	my $query_getvalues = "select distinct ATTRIBUTES.value from AERUNS join ATTRIBUTES on AERUNS.sample_id=ATTRIBUTES.sample_id where study_id = '$self->{study_id}' and assembly = '$assembly' and upper(tag) like upper('%$tag%') and AERUNS.piperun = '$self->{piperun}'";
	if ($self->{only_finished}){
	    $query_getvalues = $query_getvalues." and AERUNS.finished";
	}
	$sth = $self->{plant_db}->select($query_getvalues);
	next unless $sth->rows;
	$tag=~s/ +/_/g; #spaces used to separate dimensions, swap them out
	$tag=~s/=/:/g; #'=' used to separate tag and value, swap them out
	$dimensions{$tag} = [];
	while (my $row = $sth->fetchrow_hashref) {
	    my $val = $row->{value};
	    $val=~s/ +/_/g; #as above
	    $val=~s/=/:/g;
	    $val = lc($val);
	    push $dimensions{$tag},$val;
	}
    }
    my $subgroup = 0;
    my $samples = join ', ', (keys %sample_run);
#    my @views = map { "$_=$_" } (keys %sample_run);
#    my $view = join ' ', @views;
    my @dim_a = map { 'dim'.(shift @dim)."=$_"  } (keys %dimensions);
    my $dim_string = join ' ', @dim_a;
    my $parent = $self->{study_id}.'_composite';
    my $samp_indent = "\t"; #each sample = a 'view'
    my $run_indent = "\t\t"; 

    if ($dim_string){
	my $query_yesdim = "update STUDY set has_dim = TRUE where study_id = '$self->{study_id}'";
	$self->{plant_db}->select($query_yesdim);
    }
    print $fh "track $parent\n";
    print $fh "compositeTrack on\n";
    print $fh "shortLabel $self->{study_id}\n";
    print $fh "longLabel ENA runs from study $self->{study_id} aligned to $assembly\n";
#    print $fh "subGroup".++$subgroup." view Views $view\n";
    for my $att_tag (keys %dimensions){
	my @tag_a = map { "$_=$_" } @{$dimensions{$att_tag}};
	my $tag_string = join ' ', @tag_a;
	print $fh "subGroup".++$subgroup." $att_tag attribute_$att_tag $tag_string\n";
    }
    print $fh "dimensions $dim_string\n" if $dim_string;
    print $fh "type bam\n";
    print $fh "\n";

    for my $samp (keys %sample_run) {
	print $fh "${samp_indent}track $samp\n";
	print $fh "${samp_indent}parent $parent\n";
	print $fh "${samp_indent}shortLabel $samp\n";
#	print $fh "${samp_indent}view $samp\n";
	print $fh "${samp_indent}visibility dense\n";
	print $fh "${samp_indent}type bam\n";
	print $fh "\n";
	for my $run (@{$sample_run{$samp}}){
	    my $bigurl;
	    my $expect_place;
	    if (! $self->{only_finished}){ #if we are using unfinished crams (no ENA ftp location yet)
		my $query_notfin = "select cram_url from AERUNS where biorep_id = '$run' and not finished";
		my $exsth = $self->{plant_db}->select($query_notfin);
		if ($exsth->rows) { 
		    $expect_place = "AERUNS table, row cram_url";
		    $bigurl = $exsth->fetchrow_hashref->{cram_url};
		}
	    }
	    if (! $bigurl){ #if $bigurl is undef by now there should be an ENA location for the cram file 
		$expect_place = "CRAMS table, row filename";
		my $query_bigurl = "select CRAMS.filename from CRAMS join AERUNS on (CRAMS.md5 = AERUNS.md5_sum) where AERUNS.biorep_id = '$run'";
		$bigurl = $self->{plant_db}->select($query_bigurl)->fetchrow_hashref->{filename};
	    }
	    die "can't get cram url for run $run of sample $samp ($self->{study_id}) from $expect_place\n" unless $bigurl;

	    my @ind_dims = ();
	    foreach (keys %dimensions){
		my $query_ind_dim = "select value from ATTRIBUTES where sample_id = '$samp' and upper(tag) like upper('%$_%')";
		$sth = $self->{plant_db}->select($query_ind_dim);
		if ($sth->rows){
		    my $val = $sth->fetchrow_hashref->{value};
		    $val = lc($val);
		    $val=~s/ +/_/g;
		    push @ind_dims, "$_=$val";
		}
	    }
	    my $dims_string = join ' ',@ind_dims;
	    print $fh "${run_indent}track $run\n";
	    print $fh "${run_indent}parent $samp on\n";
	    print $fh "${run_indent}subGroups $dims_string\n" if $dims_string;
	    print $fh "${run_indent}bigDataUrl $bigurl\n";
	    print $fh "${run_indent}type bam\n";
	    print $fh "${run_indent}shortLabel $run\n";
	    print $fh "${run_indent}longLabel ENA run $run aligned to assembly $assembly\n";
	    print $fh "\n";
	}
    }

    close $fh;
    chmod 0666, $trackDb_txt;

}

sub _LoadConf {

    my $self = shift @_;
    my $dirname = dirname(__FILE__);
    my $config_file = "$dirname/config.pl";
    die "can't find config at $config_file \n" unless -e $config_file;
    $self->{'config_hash'} = read_config_file($config_file);
	
}

sub _dbconnect {

    my $self = shift @_;
    $self->{plant_db} = THP::DB->new(
	$self->{config_hash}->{DB}{name},
	$self->{config_hash}->{DB}{host},
	$self->{config_hash}->{DB}{port},
	$self->{config_hash}->{DB}{user},
	$self->{config_hash}->{DB}{pw}
	);
}


sub write_output {

    my $self = shift;
#    $self->dataflow_output_id( {
#	'organism'    => $self->param('organism'),
#	'PIPERUN'     => $self->param('PIPERUN')
#			       }, 1);

}

sub post_cleanup {

    my $self = shift;
    $self->{plant_db}->logout();

}

1;
