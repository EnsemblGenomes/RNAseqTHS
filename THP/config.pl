# https://metacpan.org/pod/Config::File

storage = /nfs/production/panda/ensemblgenomes/development/mrossello/thp
skipped = /nfs/production/panda/ensemblgenomes/development/mrossello/thp/skipped   #details of skipped crams
registry_output = /nfs/production/panda/ensemblgenomes/development/mrossello/thp/registry_output  #track hub registry can be temperamental. reports and errors get logged here

division = plants #options (May 2019): ensembl, plants, metazoa, fungi, protists, wbps
quality = 70
AEGET[seqer] = https://www.ebi.ac.uk/fg/rnaseq/api/
AEGET[species] = https://www.ebi.ac.uk/fg/rnaseq/api/json/$quality/getOrganisms/$division
AEGET[runsXorg] = https://www.ebi.ac.uk/fg/rnaseq/api/json/$quality/getRunsByOrganism/
AEGET[runsXstudy] = https://www.ebi.ac.uk/fg/rnaseq/api/json/$quality/getRunsByStudy/
#FindCrams.pm expects following columns from runsXorg
AEGET[expected_cols][study_id] = STUDY_ID #ie: look for string 'STUDY_ID' in JSON to correspond to $study_id in code and in database tables
AEGET[expected_cols][sample_id] = SAMPLE_IDS
AEGET[expected_cols][biorep_id] = BIOREP_ID
AEGET[expected_cols][run_id] = RUN_IDS
AEGET[expected_cols][org] = ORGANISM
AEGET[expected_cols][ref_org] = REFERENCE_ORGANISM 
AEGET[expected_cols][status] = STATUS
AEGET[expected_cols][assembly] = ASSEMBLY_USED
AEGET[expected_cols][ena_date] = ENA_LAST_UPDATED
AEGET[expected_cols][ae_date] = LAST_PROCESSED_DATE
AEGET[expected_cols][cram_url] = CRAM_LOCATION
AEGET[expected_cols][quality] = MAPPING_QUALITY

ensdivision = EnsemblPlants # options EnsemblVertebrates,EnsemblMetazoa,EnsemblPlants,EnsemblProtists,EnsemblFungi,"EnsemblBacteria]
ENSGET[genomes] = http://rest.ensembl.org/info/genomes/division/$ensdivision?content-type=application/json
metatags = cultivar%dev-stage%dev_stage%geo_loc_name%tissue  #'%' separated list of sample attributes to look for to make dimensions

enastudy = ERP014374 #study that crams are archived under (with ENA)
ENAGET[filereport] = https://www.ebi.ac.uk/ena/data/warehouse/filereport?accession=$enastudy&result=analysis&fields=last_updated,submitted_ftp,submitted_md5,analysis_accession,analysis_title&download=txt
#EnaStart.pm needs the following columns from ENA API call above. 
ENAGET[expected_cols][last_updated] = last_updated
ENAGET[expected_cols][submitted_ftp] = submitted_ftp
ENAGET[expected_cols][submitted_md5] = submitted_md5
ENAGET[expected_cols][analysis_acc] = analysis_accession
ENAGET[expected_cols][analysis_title] = analysis_title
# below variables are concerned with getting metadata for study and samples from ENA
ENAGET[view] = https://www.ebi.ac.uk/ena/data/view/REPLACE&display=xml
ENAGET[att_ignore] = ENA-SPOT-COUNT ENA-BASE-COUNT ENA-FIRST-PUBLIC ENA-LAST-UPDATE #these sample attributes are not needed

ENAUSER[name] = Webin-1498
ENAUSER[pw] = mrossello1
ENAUSER[ftphost] = webin.ebi.ac.uk
ENAUSER[posturl] = https://www.ebi.ac.uk/ena/submit/drop-box/submit/
ENAUSER[testurl] = https://wwwdev.ebi.ac.uk/ena/submit/drop-box/submit/
ENAUSER[test] = 0  #0 = off (use ENAUSER[posturl])  1 = on (use ENAUSER[testurl] ). If you want to do tests can alternatively set parameter 'ACTION' => 'VALIDATE'
ENAUSER[center] = EBI  # only needed if your Webin account is a broker account (comment out otherwise)

UMASK = 0000 #file and directory writing permissions. opposite of chmod. so 0111 = u,g,o can NOT execute
ENAVIEW = https://www.ebi.ac.uk/ena/data/view/
EMAIL = helpdesk@ensemblgenomes.org #contact to whom questions regarding the track hub should be directed.
THRACC[user] = ensemblplants
THRACC[pw] = testing
THRACC[ftp] = ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs
THRACC[path] = /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs
THRACC[server] = https://www.trackhubregistry.org

THRTEST[on] = 0 #1 = all test parameters used, 0 = above production paramters used
THRTEST[user] = ensemblplants
THRTEST[pw] = testing
THRTEST[ftp] = ftp://ftp.ensemblgenomes.org/pub/misc_data/plant_TH
THRTEST[path] = /nfs/ensemblgenomes/ftp/pub/misc_data/plant_TH
THRTEST[server] = http://www-test.trackhubregistry.org

DB[name] = TrackHubPipeline
DB[host] = mysql-ens-plants-prod-2
DB[port] = 4208
DB[user] = ensrw
DB[pw] = scr1b3d3

