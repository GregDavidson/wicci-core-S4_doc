-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('doc-schema.sql', '$Id');

--	Wicci Project - Associating doc_refs with page_uris

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * doc_page_rows

SELECT create_ref_type('doc_page_refs');

CREATE TABLE IF NOT EXISTS doc_page_rows (
	ref doc_page_refs PRIMARY KEY,
	uri page_uri_refs UNIQUE NOT NULL REFERENCES page_uri_rows
	CHECK(ref_id(ref) = ref_id(uri)),
--	doc doc_refs NOT NULL REFERENCES doc_keys
	doc doc_refs REFERENCES doc_keys ON DELETE CASCADE
);
COMMENT ON TABLE doc_page_rows IS
'aka wicci_urls, represents default contents of all wicci sites,
How do we deal with major changes in documents?
Do we update all graft  transaction references or do we
rewrite regular uris into permanent uris???';
COMMENT ON COLUMN doc_page_rows.uri
IS 'Could be derived from ref  - but how to do so portably
and retain the reference?';
COMMENT ON COLUMN doc_page_rows.doc
IS 'Normally this should exist, but if, e.g., it was desired to
create a site or a page and then give it content we allow null';

SELECT declare_ref_class_with_funcs('doc_page_rows');

INSERT INTO doc_page_rows(ref, uri, doc)
VALUES (doc_page_nil(), page_uri_nil(), doc_nil());

-- * large_object

CREATE TABLE IF NOT EXISTS large_object_docs (
	uri_ page_uri_refs PRIMARY KEY REFERENCES page_uri_rows,
	lang_ doc_lang_name_refs NOT NULL REFERENCES doc_lang_name_rows,
	length_ bigint,
	lo_ OID NOT NULL
);
