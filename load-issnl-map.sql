create temp table issns (like issn_to_issnl);

\copy issns from _MAP_FILE_ csv delimiter e'\t' header

insert into issn_to_issnl (issn, issn_l) (
    select issn, issn_l
    from issns
) on conflict (issn) do update
    set issn_l = excluded.issn_l
;
