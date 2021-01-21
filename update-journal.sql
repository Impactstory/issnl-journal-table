insert into journal (issn_l, issns) (
    select
        issn_l,
        jsonb_agg(to_jsonb(issn)) as issns
    from issn_to_issnl
    where issn_l is not null
    group by 1
) on conflict (issn_l) do update
    set issns = excluded.issns
;
