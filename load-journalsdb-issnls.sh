#!/bin/bash
#
# retrieve issn to issn-l mappings from JournalsDB

set -e

: ${DATABASE_URL:?environment variable must be set}

workdir=$(mktemp -d)
echo "*** working in $workdir ***"

# get the issn_l and issns for every journal

curl -s 'http://api.journalsdb.org/journals?attrs=issn_l,issns' > "$workdir/journals.json"

# bail if the file looks too small, we're expecting > 90k journals

num_journals=$(jq '.journals | length' $workdir/journals.json)

if [ $num_journals -lt "90000" ]; then
    echo "expected at least 90k journals in journalsdb file, got $num_journals"
    exit 1
fi

echo "got $num_journals journals"

# upsert mappings to postgres table

echo "*** loading journalsdb list to postgres ***"

psql $DATABASE_URL <<SQL
    begin;

    \\echo loading json blob from $workdir/journals.json

    create temp table tmp_journalsdb_file (journals_object jsonb);

    \\copy tmp_journalsdb_file from program 'jq -c . $workdir/journals.json'

    \\echo extracting journal objects

    create temp table tmp_journalsdb_journals (issn_l text, issns jsonb);

    insert into tmp_journalsdb_journals (
        select * from jsonb_populate_recordset(null::tmp_journalsdb_journals, (select journals_object->'journals' from tmp_journalsdb_file))
    );

    \\echo extracting and overwriting issn to issn_l mappings

    create temp table tmp_issn_to_issn_l (like journalsdb_issn_to_issn_l);

    insert into tmp_issn_to_issn_l (
        select jsonb_array_elements_text(issns) as issn, issn_l from tmp_journalsdb_journals
    );

    delete from journalsdb_issn_to_issn_l;

    insert into journalsdb_issn_to_issn_l (
        select issn, max(issn_l) from tmp_issn_to_issn_l group by 1
    );

    \\echo updating journal table

    create temp table tmp_jdb_issns as (select issn_l, jsonb_agg(issn) as issns from journalsdb_issn_to_issn_l group by 1);

    insert into journal (issn_l, issns) (
        select issn_l, issns from tmp_jdb_issns
    ) on conflict (issn_l) do update set issns = excluded.issns;

    commit;
SQL

