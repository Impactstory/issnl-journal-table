-- set journal title and publisher from crossref or issn metadata
-- journal_*_titles view definitions are in this repo

update journal
set
    title = btrim(coalesce(c_title, i_title), '"'),
    publisher = btrim(c_publisher, '"')
from (
    select
        issn_l,
        c.title as c_title,
        i.title as i_title,
        c.publisher as c_publisher
    from
        journal j
        left join journal_crossref_titles c using (issn_l)
        left join journal_issn_titles i using (issn_l)
) x where journal.issn_l = x.issn_l;
