#!/bin/bash

: ${DATABASE_URL:?environment variable must be set}

# STEP 1 (do once): run init-tables.sql or create equivalent tables in your DB
# STEP 2 (do as often as needed): insert any issn to issn_l overrides to table issn_to_issnl_manual
# STEP 3 (do as often as needed): insert any publisher or title overrides to table journal_properties_manual

# STEP 4 (do all remaining steps as often as you want to update the table):
# download the issn_to_issn-l table from issn.org, load to table issn_to_issn_l, apply overrides
./01-get-issnl-table.sh

# STEP 5: populate column journal.issns by grouping by issn_l
./02-update-pg-journals.sh

# STEP 6: populate the fields journal.api_raw_crossref and journal.api_raw_issn with the respective json API responses

# STEP 6.1 (optional, saves time): initialize raw api colums from https://ourresearch-public.s3-us-west-2.amazonaws.com/journal-api-raw.csv.gz
# load to a temp table and update the corresponding rows in journal, by issn_l

# STEP 6.2: update raw API colums by calling APIs
# this is normally done by running https://github.com/ourresearch/oadoi/blob/master/call_journal_apis.py on heroku
# you should be able to run it locally by cloning the oadoi repo and running `python2 call_journal_apis.py`
# if you set the DATABASE_URL environment variable it should get picked up here: https://github.com/ourresearch/oadoi/blob/master/app.py#L67
# this may take several hours, especially if you didn't pre-populate from the csv
heroku run -a oadoi python call_journal_apis.py

# STEP 7: set journal.title and journal.publisher from API responses, apply overrides
psql $DATABASE_URL < 03-update-journal-titles.sql
