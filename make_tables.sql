
/*
reset existing DB:
*/

DROP TABLE IF EXISTS CRAMS;
DROP TABLE IF EXISTS ORGS;
DROP TABLE IF EXISTS AERUNS;
DROP TABLE IF EXISTS ENASUBS;
DROP TABLE IF EXISTS STUDY;
DROP TABLE IF EXISTS SAMPLE;
DROP TABLE IF EXISTS ATTRIBUTES;
DROP TABLE IF EXISTS NAME_CHECK;

/*
set up DB:
*/


CREATE TABLE IF NOT EXISTS CRAMS (
    analysis_id VARCHAR(12) NOT NULL,
    run_id VARCHAR(12),
    title TINYTEXT,
    filename VARCHAR(150),
    md5 CHAR(32),
    date DATE NOT NULL,
    file_exists BOOLEAN,
    piperun TINYINT,
    finished BOOLEAN DEFAULT 0,
    PRIMARY KEY (analysis_id)
);

CREATE TABLE IF NOT EXISTS ORGS (
    organism VARCHAR(200) NOT NULL,
    reference_organism VARCHAR(150) NOT NULL,
    piperun TINYINT,
    finished BOOLEAN,
    PRIMARY KEY (organism,reference_organism)
);

CREATE TABLE IF NOT EXISTS AERUNS (
    biorep_id VARCHAR(12) NOT NULL,
    run_id VARCHAR(12),
    cram_url VARCHAR(150),
    md5_sum CHAR(32),
    sample_id VARCHAR(14),
    study_id VARCHAR(14),
    assembly VARCHAR(60),
    org VARCHAR(150),
    ref_org VARCHAR(150),
    ena_date DATE,
    ae_date DATE,
    quality SMALLINT,
    status VARCHAR(20),
    piperun TINYINT,
    uploaded BOOLEAN DEFAULT 0,
    submitted BOOLEAN DEFAULT 0,
    finished BOOLEAN DEFAULT 0,
    PRIMARY KEY (biorep_id)
);

CREATE TABLE IF NOT EXISTS ENASUBS (
    analysis_id VARCHAR(12) NOT NULL,
    run_id VARCHAR(12) NOT NULL,
    biorep_id VARCHAR(50),
    submission_id VARCHAR(12),
    piperun TINYINT,
    PRIMARY KEY (analysis_id,run_id)
);

CREATE TABLE IF NOT EXISTS STUDY (
    study_id VARCHAR(12) NOT NULL,
    prj_id VARCHAR(12),
    alias TINYTEXT,
    title TEXT,
    abstract TEXT,
    description TEXT,
    piperun TINYINT,
    has_samples BOOLEAN DEFAULT 0,
    has_dim BOOLEAN DEFAULT 0,
    written BOOLEAN DEFAULT 0,
    finished BOOLEAN DEFAULT 0,
    PRIMARY KEY (study_id)
);

CREATE TABLE IF NOT EXISTS SAMPLE (
    sample_id VARCHAR(12) NOT NULL,
    primary_id VARCHAR(12),
    alias TINYTEXT,
    center TINYTEXT,
    scientific_name TINYTEXT,
    title TEXT,
    description TEXT,
    piperun TINYINT,
    written BOOLEAN DEFAULT 0,
    PRIMARY KEY (sample_id)
);

CREATE TABLE IF NOT EXISTS ATTRIBUTES (
    sample_id VARCHAR(12) NOT NULL,
    tag VARCHAR(100),
    value TINYTEXT,
    piperun TINYINT,
    PRIMARY KEY (sample_id, tag) 
);

CREATE TABLE IF NOT EXISTS NAME_CHECK (
    species_production_name VARCHAR(150) NOT NULL,
    assembly_accession VARCHAR(20),
    assembly_name VARCHAR(150) NOT NULL,
    assembly_default VARCHAR(150),
    url_name VARCHAR(150),
    alt VARCHAR(150),
    piperun TINYINT,
    PRIMARY KEY (species_production_name, assembly_name) 
);

