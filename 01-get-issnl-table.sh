#!/bin/bash

workdir=$(mktemp -d)

echo working in $workdir

wget \
    --directory=$workdir \
    --no-check-certificate \
    https://www.issn.org/wp-content/uploads/2014/03/issnltables.zip

unzip $workdir/issnltables.zip -d $workdir

mv $workdir/*.ISSN-to-ISSN-L.txt $workdir/issn-table.tsv

lines=$(wc -l $workdir/issn-table.tsv | cut -f1 -d' ')

if [ $lines -lt "2000000" ]; then
    echo "expected at least 2M lines in issn to issn-l file, got $lines"
    exit 1
fi

echo loading to bigquery

bq load \
    --project_id='unpaywall-bhd' \
    --replace \
    --skip_leading_rows=1 \
    --source_format=CSV \
    --field_delimiter '\t' \
    --schema 'issn:string,issn_l:string' \
    'richard.issn_to_issnl' \
    $workdir/issn-table.tsv
