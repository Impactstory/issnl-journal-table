#!/bin/bash

# get issn to issn-l mapping used by our dois from bq
# save the issn-l and associated issns in the pg journal table

: ${DATABASE_URL:?environment variable must be set}

# extract the view to a temp table
# because views can't be extracted directly to files

echo extracting view to temp table

bq_temp_table="richard.tmp_our_issns_$RANDOM"

bq query \
    --project_id='unpaywall-bhd' \
    --use_legacy_sql=false \
    --destination_table=$bq_temp_table \
    --max_rows=0 \
    "select * from richard.our_issn_to_issnl"

# extract the mapping file to CSV and delete the temp table

echo exporting temp table to gcs

gcs_csv="gs://unpaywall-grid/issn-to-issnl-$RANDOM.csv"

bq extract \
    --project_id='unpaywall-bhd' \
    --format=csv \
    $bq_temp_table \
    $gcs_csv

bq rm -f \
    --project_id='unpaywall-bhd' \
    $bq_temp_table

# download the CSV and delete the remote file

workdir=$(mktemp -d)
local_csv=$workdir/our-issn-to-issnl.csv

echo "downloading $gcs_csv -> $local_csv"
gsutil cp $gcs_csv $local_csv
gsutil rm $gcs_csv

# upsert journal table issnl to issn list mappings

echo updating pg journal table

sed "s|_ISSN_CSV_|$local_csv|" update-journal.sql | psql $DATABASE_URL
