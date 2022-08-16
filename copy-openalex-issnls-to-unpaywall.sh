#!/bin/bash

# copy issn to issn-l mappings from OpenAlex to Unpaywall

set -e

: ${DATABASE_URL:?environment variable (oadoi/unpaywall postgres db) must be set}
: ${OPENALEX_DB_URL:?environment variable (openalex postgres db) must be set}

workdir=$(mktemp -d)
echo "*** $0 working in $workdir ***"

issns_csv=$workdir/issns.csv

echo "*** dumping issn list from openalex ***"

# export from openalex
psql $OPENALEX_DB_URL -c "\\copy (select jsonb_array_elements_text(issns::jsonb) as issn, issn as issn_l, journal_id from mid.journal where merge_into_id is null) to $issns_csv csv"

# bail if the file looks too small, we're expecting > 150k issns

num_issns=$(wc -l $issns_csv | cut -d ' ' -f 1)

if [ $num_issns -lt "150000" ]; then
    echo "expected at least 150k issnss in issn mapping, got $num_issns"
    exit 1
fi

echo "got $num_issns issns"

# upsert mappings to postgres table

echo "*** loading openalex list to unpaywall ***"

pg_issn_table=openalex_issn_to_issnl

psql $DATABASE_URL <<SQL
    begin;

    \\echo load $issns_csv
    create temp table tmp_openalex_journals (like $pg_issn_table);
    \\copy tmp_openalex_journals (issn, issn_l, journal_id) from $issns_csv csv

    \\echo replacing $pg_issn_table contents
    delete from $pg_issn_table;

    insert into $pg_issn_table (issn, issn_l, journal_id) (
        select issn, max(issn_l), max(journal_id) from tmp_openalex_journals group by 1
    );

    \\echo updating journal table
    create temp table tmp_journal_issns as (select issn_l, jsonb_agg(issn) as issns from $pg_issn_table group by 1);

    insert into journal (issn_l, issns) (
        select issn_l, issns from tmp_journal_issns
    ) on conflict (issn_l) do update set issns = excluded.issns;

    commit;

    vacuum analyze $pg_issn_table;
SQL

