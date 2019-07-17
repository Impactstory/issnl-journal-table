create or replace view journal_crossref_titles as (
SELECT journal.issn_l,
    (journal.api_raw_crossref -> 'message'::text) ->> 'title'::text AS title
   FROM journal
);
