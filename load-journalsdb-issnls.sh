#!/bin/bash

# copy issn to issn-l mappings from JournalsDB to postgres

set -e

: ${DATABASE_URL:?environment variable must be set}

workdir=$(mktemp -d)
echo "*** $0 working in $workdir ***"

journals_json="$workdir/journals.json"

# get the issn_l and issns for every journal

${0%/*}/retrieve-journalsdb-issnls.sh $journals_json

# bail if the file looks too small, we're expecting > 90k journals

num_journals=$(jq '.journals | length' $journals_json)

if [ $num_journals -lt "90000" ]; then
    echo "expected at least 90k journals in journalsdb file, got $num_journals"
    exit 1
fi

echo "got $num_journals journals"

# upsert mappings to postgres table

echo "*** loading journalsdb list to postgres ***"

pg_issn_table=journalsdb_issn_to_issn_l

psql $DATABASE_URL <<SQL
    begin;

    \\echo loading json blob from $journals_json

    create temp table tmp_journalsdb_file (journals_object jsonb);

    \\copy tmp_journalsdb_file from program 'jq -c . $journals_json'

    \\echo extracting journal objects

    create temp table tmp_journalsdb_journals (issn_l text, issns jsonb, id text);

    insert into tmp_journalsdb_journals (
        select * from jsonb_populate_recordset(null::tmp_journalsdb_journals, (select journals_object->'journals' from tmp_journalsdb_file))
    );

    \\echo extracting and overwriting issn to issn_l mappings

    create temp table tmp_issn_to_issn_l (like $pg_issn_table);

    insert into tmp_issn_to_issn_l (issn, issn_l, journalsdb_id) (
        select jsonb_array_elements_text(issns) as issn, issn_l, id as journalsdb_id from tmp_journalsdb_journals
    );

    delete from $pg_issn_table;

    insert into $pg_issn_table (issn, issn_l, journalsdb_id) (
        select issn, max(issn_l), max(journalsdb_id) from tmp_issn_to_issn_l group by 1
    );

    \\echo updating journal table

    create temp table tmp_jdb_issns as (select issn_l, jsonb_agg(issn) as issns from $pg_issn_table group by 1);

    insert into journal (issn_l, issns) (
        select issn_l, issns from tmp_jdb_issns
    ) on conflict (issn_l) do update set issns = excluded.issns;

    commit;
SQL

