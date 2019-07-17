#!/bin/bash

### get issn to issn-l mapping used by our dois

echo extracting view to temp table

bq_temp_table="richard.tmp_our_issns_$RANDOM"

bq query \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    "select * from richard.our_issn_to_issnl"

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/rorr/issn-to-issnl-$RANDOM.csv"

bq extract \
    --project_id='unpaywall-bhd' \
    --format=csv \
    $bq_temp_table \
    $gcs_csv

bq rm -f \
    --project_id='unpaywall-bhd' \
    $bq_temp_table

workdir=$(mktemp -d)
local_csv=$workdir/our-issn-to-issnl.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv

### use downloaded issn to issl mappings to update journal table

sed "s|_ISSN_CSV_|$local_csv|" update-journal.sql |
    psql -h ec2-18-205-92-196.compute-1.amazonaws.com \
        -p 5432 -U u1prl2s64bmg6e -d dds97qbhb1bu4i


