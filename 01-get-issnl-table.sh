#!/bin/bash
#
# retrieve issn to issn-l mappings from issn.org
# load them to bigquery and postgres

: ${DATABASE_URL:?environment variable must be set}

workdir=$(mktemp -d)
echo "*** working in $workdir ***"

# get the issn to issn-l map file
# date in file URL is static but file is updated daily

echo "*** getting issn to issn-l map file ***"

wget \
    --directory=$workdir \
    --no-check-certificate \
    https://www.issn.org/wp-content/uploads/2014/03/issnltables.zip

unzip $workdir/issnltables.zip -d $workdir

# give the issn to issn-l map file a fixed name

map_file=$workdir/issn-table.tsv

mv $workdir/*.ISSN-to-ISSN-L.txt $map_file

# bail if the file looks too small,
# because we're replacing the whole bigquery table, not updating

lines=$(wc -l $map_file | cut -f1 -d' ')

if [ $lines -lt "2000000" ]; then
    echo "expected at least 2M lines in issn to issn-l file, got $lines"
    exit 1
fi

# upsert mappings to postgres table

echo "*** loading mappings to postgres ***"

sed "s|_MAP_FILE_|$map_file|" load-issnl-map.sql | psql $DATABASE_URL

# replace mappings in bigquery

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
