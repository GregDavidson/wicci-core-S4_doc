-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('doc-code.sql', '$Id');

--	Wicci Project
--	ref type doc_refs (hierarchical versionable document) code

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** casts and conversions

CREATE OR REPLACE
FUNCTION doc_page_uri(doc_page_refs)
RETURNS page_uri_refs AS $$
	SELECT unchecked_page_uri_from_id( ref_id($1) )
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION doc_page_uri(doc_page_refs)
IS 'Simply retags the id; could instead fetch the uri field
from the row but this should be cheaper.';

DROP CAST IF EXISTS (doc_page_refs AS page_uri_refs) CASCADE;
CREATE CAST (doc_page_refs AS page_uri_refs)
WITH FUNCTION doc_page_uri(doc_page_refs);

CREATE OR REPLACE
FUNCTION try_doc_page(page_uri_refs)
RETURNS doc_page_refs AS $$
	SELECT ref FROM doc_page_rows WHERE uri = $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_doc_page(page_uri_refs)
RETURNS doc_page_refs AS $$
	SELECT non_null(
		try_doc_page($1), 'find_doc_page(page_uri_refs)'
	)
$$ LANGUAGE SQL;

-- ** I/O

CREATE OR REPLACE
FUNCTION doc_page_ref_in(text) RETURNS doc_page_refs AS $$
	SELECT unchecked_doc_page_from_id(ref_id(find_page_uri($1)))
$$ LANGUAGE SQL;

COMMENT ON FUNCTION doc_page_ref_in(text)
IS 'Construct a doc_page reference which may not yet
be associated with a row. Used when constructing such rows.
Does not check referential integrity!';

CREATE OR REPLACE
FUNCTION try_doc_page(text) RETURNS doc_page_refs AS $$
	SELECT ref FROM doc_page_rows
	WHERE uri = try_page_uri($1) 
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_doc_page(text) RETURNS doc_page_refs AS $$
	SELECT non_null(try_doc_page($1), 'find_doc_page(text)', $1)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION doc_page_text(doc_page_refs) RETURNS text AS $$
	SELECT page_uri_text(uri) FROM doc_page_rows WHERE ref = $1
$$ LANGUAGE SQL;

SELECT type_class_in(
	'doc_page_refs', 'doc_page_rows', 'try_doc_page(text)'
);

SELECT type_class_out(
	'doc_page_refs', 'doc_page_rows',
	'doc_page_text(doc_page_refs)'
);

SELECT type_class_op_method(
	'doc_page_refs', 'doc_page_rows',
	'ref_text_op(refs)',
	'doc_page_text(doc_page_refs)'
);

-- ** Construction

CREATE OR REPLACE FUNCTION try_get_doc_page(
	page_uri_refs, doc_refs = doc_nil()
) RETURNS doc_page_refs AS $$
	DECLARE
		_doc doc_refs
			:= CASE WHEN is_nil($2) THEN NULL ELSE $2 END;
		_doc_page RECORD;					--	doc_page_rows%ROWTYPE;
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_doc_page(page_uri_refs, doc_refs)';
	BEGIN
		LOOP
			SELECT * INTO _doc_page FROM doc_page_rows
			WHERE uri = $1;
			IF FOUND THEN
				IF _doc IS NULL
				OR _doc_page.doc IS NOT DISTINCT FROM _doc THEN
					RETURN _doc_page.ref;
				END IF;
				IF _doc_page.doc IS NOT NULL THEN
					RAISE EXCEPTION '%: % page % <> %',
					this, $1, _doc_page.doc, $2;
				END IF;
			END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % %', this, $1, $2;
			END IF;
			kilroy_was_here := true;
			BEGIN
				IF FOUND THEN
					UPDATE doc_page_rows SET doc = _doc
					WHERE ref = _doc_page.ref;
				ELSE
					INSERT INTO doc_page_rows(ref, uri, doc)
					VALUES( unchecked_doc_page_from_id(ref_id($1)), $1, _doc );
				END IF;
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_doc_page(page_uri_refs, doc_refs)
RETURNS doc_page_refs AS $$
	SELECT non_null(
		try_get_doc_page($1, $2),
		'get_doc_page(page_uri_refs, doc_refs)',
		'uri', $1::text, 'doc', COALESCE($2::text, 'NULL')
	)
$$ LANGUAGE SQL;

COMMENT ON FUNCTION get_doc_page(page_uri_refs, doc_refs)
IS 'page uri, doc --> page; maybe creating new row, maybe
filling in non-null value for doc';

CREATE OR REPLACE
FUNCTION try_get_page_doc(page_uri_refs, doc_refs)
RETURNS doc_refs AS $$
	SELECT CASE WHEN page IS NULL THEN NULL
		ELSE $2
	END FROM try_get_doc_page($1, $2) page;
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION get_page_doc(page_uri_refs, doc_refs)
RETURNS doc_refs AS $$
	SELECT $2 FROM get_doc_page($1, $2) page;
$$ LANGUAGE SQL;

-- ** Content Mutation and Access

CREATE OR REPLACE FUNCTION update_doc_page_content(
	doc_page_refs, doc_refs
) RETURNS doc_page_refs AS $$
	UPDATE doc_page_rows SET doc = $2
	WHERE ref = $1 RETURNING ref
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_doc_page_doc(doc_page_refs)  RETURNS doc_refs AS $$
	SELECT doc FROM doc_page_rows WHERE ref = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION doc_page_doc(doc_page_refs) RETURNS doc_refs AS $$
	SELECT non_null(
		try_doc_page_doc($1), 'doc_page_doc(doc_page_refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_page_doc(page_uri_refs)  RETURNS doc_refs AS $$
	SELECT doc FROM doc_page_rows WHERE uri = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION find_page_doc(page_uri_refs) RETURNS doc_refs AS $$
	SELECT non_null(
		try_page_doc($1), 'find_page_doc(page_uri_refs)'
	)
$$ LANGUAGE sql;

-- * static document pages

CREATE OR REPLACE FUNCTION try_get_static_xfiles_page(
	file_name text,
	doc_lang doc_lang_name_refs,
	file_size bigint = -1,
	file_hash hashes = hash_nil()
) RETURNS doc_page_refs AS $$
	SELECT get_doc_page(page_uri, doc)
	FROM
		xfiles_page_uri(file_name) page_uri,
		LATERAL get_static_doc($1, $2, page_uri, $3, $4) doc
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION get_static_xfiles_page(
	file_name text,
	doc_lang doc_lang_name_refs,
	file_size bigint = -1,
	file_hash hashes = hash_nil()
) RETURNS doc_page_refs AS $$
	SELECT non_null(
		try_get_static_xfiles_page($1, $2, $3, $4),
		'get_static_xfiles_page(text,doc_lang_name_refs, bigint, hashes)'
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION get_static_xfiles_page(
	text, doc_lang_name_refs,	bigint, hashes
) IS '
	find or create a static (unparsed, simple hunk of bytes) document
	and bind it to a page url
';

CREATE OR REPLACE FUNCTION get_static_xfiles_page(
	file_name text,
	doc_lang doc_lang_name_refs,
	dir_path text,
	file_size bigint = -1,
	file_hash hashes = hash_nil()
) RETURNS doc_page_refs AS $$
	SELECT get_static_xfiles_page($3 || '/' || $1, $2, $4, $5)
$$ LANGUAGE sql;
