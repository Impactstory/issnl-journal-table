create temp table tmp_crossref_issns (issn text primary key);
\copy tmp_crossref_issns from _ISSN_CSV_ csv header

insert into crossref_issn (select * from tmp_crossref_issns) on conflict do nothing;
