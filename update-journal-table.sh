#!/bin/bash

: ${DATABASE_URL:?environment variable must be set}

./01-get-issnl-table.sh
./02-update-pg-journals.sh
heroku run -a oadoi python call_journal_apis.py
psql $DATABASE_URL < 03-update-journal-titles.sql
