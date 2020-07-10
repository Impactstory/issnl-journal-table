create temp table tmp_our_issn_to_issnl (issn text, issn_l text);

\copy tmp_our_issn_to_issnl from _ISSN_CSV_ csv header

insert into journal (issn_l, issns) (
    select
        issn_l,
        jsonb_agg(to_jsonb(issn)) as issns
    from tmp_our_issn_to_issnl
    where issn_l is not null
    group by 1
) on conflict (issn_l) do update
    set issns = excluded.issns
;

create temp table all_issn_l_to_issn as (
    select
        issn_l,
        jsonb_agg(to_jsonb(issn)) as issns
    from issn_to_issnl
    where issn_l is not null
    group by issn_l
);

update journal set issns = all_issn_l_to_issn.issns from all_issn_l_to_issn where journal.issn_l = all_issn_l_to_issn.issn_l;
