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

-- * nil_ref_doc

CREATE OR REPLACE
FUNCTION nil_ref_doc_text(doc_refs) RETURNS TEXT AS $$
	SELECT 'nil_ref_doc(' || ref_id($1)::text || ')'
$$ LANGUAGE sql;

SELECT type_class_op_method(
	'doc_refs', 'abstract_doc_rows',
	'ref_text_op(refs)',
	'nil_ref_doc_text(doc_refs)'
);

-- * TABLE tree_doc_rows

CREATE OR REPLACE
FUNCTION try_doc_lang_name(doc_refs)
RETURNS doc_lang_name_refs AS $$
	SELECT CASE ref_table($1)
		WHEN 'tree_doc_rows'::regclass THEN (
			SELECT lang FROM tree_doc_rows WHERE ref = $1
		)
		WHEN 'changeset_doc_rows'::regclass THEN (
			SELECT try_doc_lang_name(base) FROM changeset_doc_rows
			WHERE ref = $1
		)
	END
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION doc_lang_name(doc_refs)
RETURNS doc_lang_name_refs AS $$
	SELECT non_null(
		try_doc_lang_name($1), 'doc_lang_name(doc_refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION tree_doc_text(
	doc_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS TEXT AS $$
	SELECT ref_env_crefs_text_op(root, $2, $3)
	FROM tree_doc_rows WHERE ref = $1
$$ LANGUAGE sql;
COMMENT ON FUNCTION tree_doc_text(doc_refs, env_refs, crefs)
IS 'produce proper document text from a tree_doc';

CREATE OR REPLACE FUNCTION new_tree_doc(
	the_root doc_node_refs, doc_lang_name_refs='text'
) RETURNS doc_refs AS $$
DECLARE
	_ref doc_refs;
	kilroy_was_here boolean := false;
	this regprocedure
		:= 'new_tree_doc(doc_node_refs, doc_lang_name_refs)';
BEGIN
	LOOP
		SELECT ref INTO _ref FROM tree_doc_rows WHERE root = $1;
		IF FOUND THEN RETURN _ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% % looping', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO tree_doc_rows(root, lang, ref)
			VALUES ($1, $2, next_doc_ref( 'tree_doc_rows' ));
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
		END;
	END LOOP;
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION new_tree_doc(
	doc_node_refs, doc_lang_name_refs
) IS 'Creating the document which holds the root of a tree.
In case the construction of the tree needs the document
ref before the document exists we allow it to be passed
to us - this is needed, e.g. in imporing xml docs,';

-- * register class tree_doc_rows

-- see xml-refs-output-code.sql section * TYPE tree_doc_node

SELECT type_class_op_method(
	'doc_refs', 'tree_doc_rows',
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'tree_doc_text(doc_refs, env_refs, crefs)'
);

-- * TABLE changeset_doc_rows

-- oftd !!!
CREATE OR REPLACE FUNCTION changeset_doc_text(
	doc_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS TEXT AS $$
	SELECT (
		SELECT oftd_ref_env_crefs_text_op(
			'ref_env_crefs_text_op(refs, env_refs, crefs)',
			graft_node_old_array(grafts),
			graft_node_new_array(grafts),
			$1::refs,
			base, $2, $3
		) FROM debug_enter(
			'changeset_doc_text(doc_refs, env_refs, crefs)',
			array_length(grafts), 'num grafts'
		) this
	) FROM changeset_doc_rows WHERE ref = $1
$$ LANGUAGE sql; COMMENT ON
FUNCTION changeset_doc_text(doc_refs, env_refs, crefs)
IS 'produce proper xml text from a changeset_doc_rows node';

-- find_ref_changeset_doc(base, grafts)
CREATE OR REPLACE		-- !!! ???
FUNCTION find_ref_changeset_doc(doc_refs, doc_node_refs[])
RETURNS doc_refs AS $$
	SELECT ref  FROM changeset_doc_rows
	WHERE base = $1 AND grafts = $2
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION make_changeset_doc(doc_refs, doc_node_refs[])
RETURNS doc_refs AS $$
DECLARE
	the_ref doc_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure :=
		'make_changeset_doc(doc_refs, doc_node_refs[])';
BEGIN LOOP
		SELECT ref INTO the_ref FROM changeset_doc_rows
		WHERE base = $1 AND grafts = $2;
		IF FOUND THEN RETURN the_ref; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO changeset_doc_rows(base, grafts) VALUES ($1, $2);
		EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % raised %!',
						this, $1, $2, 'unique_violation';
		END;
END LOOP; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_changeset_doc(
	base_ doc_refs,
	VARIADIC grafts_ doc_node_refs[] = no_doc_node_array()
) RETURNS doc_refs AS $$
	SELECT COALESCE(
		find_ref_changeset_doc($1, $2),
		make_changeset_doc($1, $2)
	) FROM debug_enter(
		'get_changeset_doc(doc_refs, doc_node_refs[])'
	) this
	WHERE debug_assert(
		this,
		is_array_ref_of('doc_node_refs', 'graft_doc_node_rows', $2::refs[]),
		$2
	) IS NOT NULL
$$ LANGUAGE sql; COMMENT ON
FUNCTION get_changeset_doc(doc_refs, doc_node_refs[])
IS 'find or make a changeset with the given fields';

CREATE OR REPLACE FUNCTION tree_path_find_(
	doc_refs, path integer[],
	grafts doc_node_refs[] = no_doc_node_array()
) RETURNS doc_node_refs AS $$
	SELECT find_by_path(root, $2, $3)
	FROM tree_doc_rows WHERE ref = $1
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION changeset_path_find_(
	doc_refs, path integer[],
	grafts doc_node_refs[] = no_doc_node_array()
) RETURNS doc_node_refs AS $$
	SELECT tree_path_find_(base, $2, grafts || $3)
	FROM changeset_doc_rows WHERE ref=$1
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION find_by_path(
	doc_refs, path integer[],
	grafts doc_node_refs[] = no_doc_node_array()
) RETURNS doc_node_refs AS $$
	SELECT CASE ref_table($1)
		WHEN 'tree_doc_rows'::regclass
	THEN tree_path_find_($1, $2, $3)
		WHEN 'changeset_doc_rows'::regclass
	THEN changeset_path_find_($1, $2, $3)
	ELSE case_failed_any_ref(
		'find_by_path(doc_refs, integer[], doc_node_refs[])',
		NULL::doc_node_refs, $1 -- unchecked_ref_null()::doc_node_refs
	)
	END
$$ LANGUAGE sql;

-- * register class changeset_doc_rows

-- still: ??
-- seevxml-refs-output-code.sql section * TYPE doc_refs

SELECT type_class_op_method(
	'doc_refs', 'changeset_doc_rows',
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'changeset_doc_text(doc_refs, env_refs, crefs)'
);

CREATE OR REPLACE
FUNCTION try_doc(refs) RETURNS doc_refs AS $$
	SELECT $1::unchecked_refs::doc_refs
	FROM typed_object_classes
	WHERE tag_ = ref_tag($1) AND type_ = 'doc_refs'::regtype
$$ LANGUAGE sql;

-- * blob_doc_rows


CREATE OR REPLACE FUNCTION try_get_blob_doc (
	full_path text, page page_uri_refs,
	lang_name doc_lang_name_refs,
	file_size bigint = -1, file_hash hashes = hash_nil()
) RETURNS doc_refs AS $$
	DECLARE
		doc RECORD;
		blob_hash hashes;
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_blob_doc(
			text, page_uri_refs, doc_lang_name_refs, bigint, hashes
		)';
	BEGIN
		LOOP
			SELECT * INTO doc FROM blob_doc_rows
			WHERE page_uri_ = page AND lang = lang_name;
			IF FOUND THEN
				IF doc.lang <> lang_name THEN
					RAISE NOTICE '% % % % stored lang is %!',
					this, $1, $2, $3, doc.lang;
				END IF;
				IF file_hash IS NOT NULL THEN
					blob_hash := blob_hash(doc.blob_);
					IF file_hash <> blob_hash THEN
						RAISE NOTICE '% % % % % stored hash is %!',
						this, $1, $2, $3, $6, blob_hash;
					END IF;
				END IF;
				RETURN doc.ref;
			END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % % %', this, $1, $2, $3;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO blob_doc_rows( blob_, page_uri_, lang )
				VALUES ( get_blob(pg_read_binary_file($1)), $2, $3 );
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % % raised %!',
					this, $1, $2, $3, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

COMMENT ON FUNCTION try_get_blob_doc(
	text, page_uri_refs,	doc_lang_name_refs, bigint, hashes
) IS '
	Finds or loads file with given path and language.
	What if lang has changed for a given file?
	Currently file_size and file are not given!!
	Does not reload file if contents or lang changed!!
';

CREATE OR REPLACE FUNCTION get_blob_doc (
	full_path text, page page_uri_refs,
	lang_name doc_lang_name_refs,
	file_size bigint = -1, file_hash hashes = hash_nil()
) RETURNS doc_refs AS $$
	SELECT non_null(
		try_get_blob_doc($1, $2, $3, $4, $5),
		'get_blob_doc(text, page_uri_refs, doc_lang_name_refs,	bigint, hashes)'
	)
$$ LANGUAGE sql;

-- * file_doc_rows

CREATE OR REPLACE FUNCTION try_get_file_doc (
	page page_uri_refs, lang_name doc_lang_name_refs,
	file_size bigint = -1, hashes = hash_nil()
) RETURNS doc_refs AS $$
	DECLARE
		doc doc_refs := NULL; -- unchecked_ref_null();
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_file_doc(
			page_uri_refs, doc_lang_name_refs, bigint, hashes
		)';
	BEGIN
		LOOP
			SELECT ref INTO doc FROM file_doc_rows
			WHERE page_uri_ = page AND lang = lang_name;
			IF FOUND THEN RETURN doc; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % %', this, $2, $3;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO file_doc_rows(page_uri_, lang)
				VALUES ($1, $2);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % raised %!',
					this, $1, $2, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

COMMENT ON FUNCTION try_get_file_doc(
	page_uri_refs, doc_lang_name_refs,	bigint, hashes
) IS '
	This storage policy should only be used during development!!
	Should we do more checking??
	Does the path hold a file??
	If we already have it, have the lang or hashes changed??
';

CREATE OR REPLACE FUNCTION get_file_doc (
	page_uri_refs, doc_lang_name_refs,
	bigint = -1, hashes = hash_nil()
) RETURNS doc_refs AS $$
	SELECT non_null(
		try_get_file_doc($1, $2, $3, $4),
		'get_file_doc(page_uri_refs, doc_lang_name_refs,	bigint, hashes)'
	)
$$ LANGUAGE sql;

-- * large_object_doc_rows

CREATE OR REPLACE FUNCTION try_get_large_object_doc(
	full_path text, page_uri_refs, doc_lang_name_refs,
	file_size bigint = -1, hashes = hash_nil()
) RETURNS doc_refs AS $$
	DECLARE
		_lo RECORD;
		lo_oid oid;
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_large_object_doc(
			page_uri_refs, doc_lang_name_refs, bigint, text
		)';
	BEGIN
		LOOP
			SELECT * INTO _lo FROM large_object_doc_rows
			WHERE page_uri_ = $2;
			IF FOUND THEN
				IF _lo.lang IS DISTINCT FROM $3 THEN
					RAISE EXCEPTION '%: % lang % <> %',
					this, $1, _lo.lang, $3;
				END IF;
				RETURN _lo.lo_;
			END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % %', this, $1, $2;
			END IF;
			kilroy_was_here := true;
			BEGIN
				RAISE NOTICE '%: SELECT lo_import(%)', this, full_path;
				lo_oid := lo_import(full_path);
				IF lo_oid IS NULL THEN
					RAISE EXCEPTION '%: lo_import(%) failed', this, $1;
				END IF;
				INSERT INTO blob_docs(page_uri_, lang, length_, lo_)
				VALUES ($2, $3, $4, lo_oid);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % raised %!',
					this, $1, $2, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION get_large_object_doc(
	full_path text, page_uri_refs, doc_lang_name_refs,
	file_size bigint = -1, hashes = hash_nil()
) RETURNS doc_refs AS $$
	SELECT non_null(
		try_get_large_object_doc($1, $2, $3, $4, $5),
		'get_large_object_doc(text, page_uri_refs, doc_lang_name_refs,	bigint, hashes)'
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION get_large_object_doc(
	text, page_uri_refs, doc_lang_name_refs,	bigint, hashes
) IS '
	find or create blob as a large object;
	currently large objects are deprecated!!
	much has changed so if we undeprecate large objects
	this code will need inspection and testing!!
';

-- ** get_static_doc

CREATE OR REPLACE
FUNCTION try_xfiles_page_uri(text)  RETURNS page_uri_refs AS $$
	SELECT try_get_page_uri(
			uri_entity_pair_nil(),
			try_get_uri_domain_name(matches[2]::citext),
			try_get_uri_path_name(matches[3])
		) FROM COALESCE(
			try_str_match($1, '^(Domain)/([^/]*)/(.*)$'),
			try_str_match($1, '^XFiles/(Domain)/([^/]*)/(.*)$'),
			try_str_match($1, '^.*/XFiles/(Domain)/([^/]*)/(.*)$'),
			try_str_match($1, '^.*/(XFiles)()/(.*)$'),
			try_str_match($1, '^(XFiles)()/(.*)$'),
			try_str_match($1, '^(Favicons)()/(.*)$'),
			try_str_match($1, '^()()/([^/].*)$')
		) matches
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION xfiles_page_uri(text) RETURNS page_uri_refs AS $$
	SELECT non_null(
		try_xfiles_page_uri($1),	'xfiles_page_uri(text)'
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION xfiles_page_uri(text)
IS 'Given a path to a file under XFiles, return ';

SELECT test_func(
	'xfiles_page_uri(text)',
	page_uri_text( try_xfiles_page_uri( '/home/greg/.Wicci/XFiles/Domain/wicci.org/Entity-Icon/friend-kas.jpg'::text ) ),
	'wicci.org/Entity-Icon/friend-kas.jpg'::text
);

SELECT test_func(
	'xfiles_page_uri(text)',
	page_uri_text( try_xfiles_page_uri( 'XFiles/Domain/wicci.org/Entity-Icon/friend-kas.jpg'::text ) ),
	'wicci.org/Entity-Icon/friend-kas.jpg'::text
);

SELECT test_func(
	'xfiles_page_uri(text)',
	page_uri_text( try_xfiles_page_uri( 'Domain/wicci.org/Entity-Icon/friend-kas.jpg'::text ) ),
	'wicci.org/Entity-Icon/friend-kas.jpg'::text
);

SELECT test_func(
	'xfiles_page_uri(text)',
	page_uri_text( try_xfiles_page_uri( '/home/greg/.Wicci/XFiles/JS/JS/cci.js' ) ),
	'/JS/JS/cci.js'
);

CREATE OR REPLACE FUNCTION page_uri_xfiles_path(page_uri_refs) RETURNS text AS $$
DECLARE
	_page RECORD;
	is_a_dir BOOLEAN;
	file_name text;
	_this regprocedure = 'page_uri_xfiles_path(page_uri_refs)';
BEGIN
  IF is_nil($1) THEN
	   RAISE EXCEPTION '%(nil)!', _this;
	END IF;
	SELECT INTO _page domain_, path_ FROM page_uri_rows WHERE ref = $1;
  IF _page IS NULL THEN
	   RAISE EXCEPTION '%: no page uri %!', _this, $1;
	END IF;
  IF is_nil(_page.path_) THEN
	   RAISE EXCEPTION '%: no path for %!', _this, $1;
	END IF;
  IF is_nil(_page.domain_) THEN
		file_name := 'XFiles/' || uri_path_name_text(_page.path_);
	ELSE
		file_name := 'XFiles/Domain/' || uri_domain_name_text(_page.domain_) || '/' || uri_path_name_text(_page.path_);
	END IF;
	BEGIN
		SELECT INTO is_a_dir is_dir
		FROM pg_stat_file(file_name) foo(size, access, modification, change, creation, is_dir);
		IF is_a_dir THEN
			RAISE EXCEPTION '%: % is a directory!', _this, file_name;
		END IF;
	EXCEPTION
	WHEN SQLSTATE '58P01' THEN	RAISE WARNING '%: % file not found', _this, file_name;
	END;
	RETURN file_name;
END
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION page_uri_xfiles_path(page_uri_refs)
IS 'given a page_uri which encodes a filename path under XFiles,
recover that path, check it for reasonableness and return it;';

SELECT test_func(
	'page_uri_xfiles_path(page_uri_refs)',
	page_uri_xfiles_path( try_page_uri( 'wicci.org/Entity-Icon/friend-kas.jpg' ) ),
	'XFiles/Domain/wicci.org/Entity-Icon/friend-kas.jpg'
);

SELECT test_func(
	'page_uri_xfiles_path(page_uri_refs)',
	page_uri_xfiles_path( try_page_uri( '/JS/JS/cci.js' ) ),
	'XFiles/JS/JS/cci.js'
);

CREATE OR REPLACE FUNCTION get_static_doc(
	file_name text,
	doc_lang doc_lang_name_refs,
	page_uri_ref page_uri_refs = NULL,
	file_size bigint = -1,
	file_hash hashes = hash_nil(),
	storage_policy regclass = NULL
) RETURNS doc_refs AS $$
	SELECT non_null(
		CASE COALESCE(storage_policy, static_doc_storage_policy())
		WHEN 'large_object_doc_rows'::regclass THEN
		get_large_object_doc(file_path, page_uri, $2, $4, $5)
		WHEN 'file_doc_rows'::regclass THEN
		get_file_doc(page_uri, $2, $4, $5)
		WHEN 'blob_doc_rows'::regclass THEN
		get_blob_doc(file_path, page_uri, $2, $4, $5)
		END,
		'get_static_doc(text,doc_lang_name_refs, page_uri_refs, bigint, hashes, regclass)'
) FROM
	COALESCE(page_uri_ref, xfiles_page_uri($1)) page_uri,
	LATERAL page_uri_xfiles_path(page_uri) file_path
$$ LANGUAGE sql;

COMMENT ON FUNCTION get_static_doc(
	text, doc_lang_name_refs, page_uri_refs, bigint, hashes, regclass
) IS 'find or create a static (unparsed, simple hunk of bytes) document';

-- * env_doc

SELECT create_env_name_type_func(
	'env_doc', 'doc_refs'
);
