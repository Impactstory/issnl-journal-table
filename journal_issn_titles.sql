create or replace view journal_issn_titles as (
     SELECT z.issn_l,
    min(z.main_title) AS main_title,
    min(z.name) AS name,
    COALESCE(min(z.main_title), min(z.name)) AS title
   FROM ( SELECT y.issn_l,
            y.issns,
                CASE
                    WHEN jsonb_typeof(y.main_title) = 'array'::text THEN y.main_title ->> 0
                    ELSE btrim(y.main_title::text, '"'::text)
                END AS main_title,
                CASE
                    WHEN jsonb_typeof(y.name) = 'array'::text THEN y.name ->> 0
                    ELSE btrim(y.name::text, '"'::text)
                END AS name
           FROM ( SELECT x.issn_l,
                    x.issns,
                    x.element -> 'mainTitle'::text AS main_title,
                    x.element -> 'name'::text AS name
                   FROM ( SELECT journal.issn_l,
                            journal.issns,
                            jsonb_array_elements(journal.api_raw_issn -> '@graph'::text) AS element
                           FROM journal) x
                  WHERE (x.element ->> '@id'::text) = ('resource/ISSN/'::text || x.issn_l)) y) z
  GROUP BY z.issn_l
);
