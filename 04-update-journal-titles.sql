update journal
set title = coalesce(c_title, i_title)
from (
    select
        issn_l,
        c.title as c_title,
        i.title as i_title
    from
        journal j
        left join journal_crossref_titles c using (issn_l)
        left join journal_issn_titles i using (issn_l)
) x where journal.issn_l = x.issn_l;
