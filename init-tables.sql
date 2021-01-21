CREATE TABLE public.issn_to_issnl (
    issn text NOT NULL,
    issn_l text NOT NULL
);


ALTER TABLE ONLY public.issn_to_issnl
    ADD CONSTRAINT issn_to_issnl_pkey PRIMARY KEY (issn);


CREATE INDEX issn_to_issnl_issn_l_idx ON public.issn_to_issnl USING btree (issn_l);

CREATE TABLE public.issn_to_issnl_manual (
    issn text NOT NULL,
    issn_l text
);

ALTER TABLE ONLY public.issn_to_issnl_manual
    ADD CONSTRAINT issn_to_issnl_manual_pkey PRIMARY KEY (issn);

CREATE TABLE public.journal (
    issn_l text NOT NULL,
    title text,
    issns jsonb,
    api_raw_crossref jsonb,
    api_raw_issn jsonb,
    publisher text,
    delayed_oa boolean DEFAULT false,
    embargo interval
);

ALTER TABLE ONLY public.journal
    ADD CONSTRAINT journal_pkey PRIMARY KEY (issn_l);
