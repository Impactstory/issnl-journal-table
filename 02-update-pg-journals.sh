#!/bin/bash

# save the issn-l and associated issns in the pg journal table

: ${DATABASE_URL:?environment variable must be set}

echo updating pg journal table

cat update-journal.sql | psql $DATABASE_URL
