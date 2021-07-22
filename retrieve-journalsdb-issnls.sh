#!/bin/bash

# retrieve issn to issn-l mappings from JournalsDB

set -e

journals_output_json=$1

workdir=$(mktemp -d)
echo "*** $0 working in $workdir ***"

# get the issn_l and issns for every journal

# page through journalsdb api

journalsdb_page=1

while [ -z "$journalsdb_max_page" ] || [ "$journalsdb_page" -le "$journalsdb_max_page" ]; do
    journalsdb_url="https://api.journalsdb.org/journals-paged?attrs=issn_l,issns&page=$journalsdb_page&per-page=100"
    out_file="$workdir/page-$journalsdb_page.json"

    echo "($journalsdb_page / $journalsdb_max_page) $journalsdb_url > $out_file"
    curl -s -f --retry 5 $journalsdb_url > $out_file

    journalsdb_max_page=$(jq -r '.pagination.pages' $out_file)
    journalsdb_page=$(($journalsdb_page + 1))
done

# concat result arrays from page files

all_pages_txt="$workdir/all-pages.txt"
echo "extracting page results to $all_pages_txt"
for page_file in $workdir/page-*.json; do
    jq '.results' $page_file >> $all_pages_txt
done

# flatten page arrays and stuff into new object

echo "merging page results to $journals_output_json"
jq -s '{journals: add}' $all_pages_txt > $journals_output_json
