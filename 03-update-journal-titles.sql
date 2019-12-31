-- set journal title and publisher from crossref or issn metadata

create function pg_temp.remove_ctrl_chars(text) returns text as
    $$ select regexp_replace($1, '[\u0000-\u001F\u007F\u0080-\u009F]', '', 'g') $$
    language sql immutable
;

with

crossref_info as (
    select journal.issn_l,
        btrim((journal.api_raw_crossref->'message')->>'title') as title,
        btrim((journal.api_raw_crossref->'message')->>'publisher') as publisher
    from journal
),

issn_org_info as (
    select
        z.issn_l,
        min(z.main_title) as main_title,
        min(z.name) as name,
        coalesce(min(z.main_title), min(z.name)) AS title
    from (
        select
            y.issn_l,
            y.issns,
            case
                when jsonb_typeof(y.main_title) = 'array' then y.main_title->>0
                else btrim(y.main_title::text, '"')
            end as main_title,
            case
                when jsonb_typeof(y.name) = 'array' then y.name->>0
                else btrim(y.name::text, '"')
            end as name
        from (
            select
                x.issn_l,
                x.issns,
                x.element->'mainTitle' as main_title,
                x.element->'name' as name
            from (
                select
                    journal.issn_l,
                    journal.issns,
                    jsonb_array_elements(journal.api_raw_issn->'@graph') as element
                from journal
            ) x
            where (x.element->>'@id') = ('resource/ISSN/' || x.issn_l)
        ) y
    ) z
    group by z.issn_l
)

update journal
set
    title = pg_temp.remove_ctrl_chars(btrim(coalesce(c_title, i_title), '"')),
    publisher = pg_temp.remove_ctrl_chars(btrim(c_publisher, '"'))
from (
    select
        issn_l,
        c.title as c_title,
        i.title as i_title,
        c.publisher as c_publisher
    from
        journal j
        left join crossref_info c using (issn_l)
        left join issn_org_info i using (issn_l)
) x
where journal.issn_l = x.issn_l;

delete from journal where publisher ~* 'crossref test';
