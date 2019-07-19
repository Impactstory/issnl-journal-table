#!/bin/bash

workdir=$(mktemp -d)

echo "*** working in $workdir ***"

echo "*** getting issn to issn-l map file ***"

wget \
    --directory=$workdir \
    --no-check-certificate \
    https://www.issn.org/wp-content/uploads/2014/03/issnltables.zip

unzip $workdir/issnltables.zip -d $workdir

map_file=$workdir/issn-table.tsv

mv $workdir/*.ISSN-to-ISSN-L.txt $map_file

lines=$(wc -l $map_file | cut -f1 -d' ')

if [ $lines -lt "2000000" ]; then
    echo "expected at least 2M lines in issn to issn-l file, got $lines"
    exit 1
fi

echo "*** loading mappings to postgres ***"

sed "s|_MAP_FILE_|$map_file|" load-issnl-map.sql |
    psql -h ec2-18-205-92-196.compute-1.amazonaws.com \
        -p 5432 -U u1prl2s64bmg6e -d dds97qbhb1bu4i


echo "*** loading mappings to bigquery ***"

bq load \
    --project_id='unpaywall-bhd' \
    --replace \
    --skip_leading_rows=1 \
    --source_format=CSV \
    --field_delimiter '\t' \
    --schema 'issn:string,issn_l:string' \
    'richard.issn_to_issnl' \
    $map_file
