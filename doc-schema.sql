-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('doc-schema.sql', '$Id');

--	Wicci Project
--	doc-refs: hierarchical multi-versioned documents schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * introduction

-- These types exists to represent hierarchically-structured,
-- versionable documents in various languages, such as html
-- (and other xml family) languages, CSS, SQL, C, JavaScript, etc.

-- --> doc_lang_name_refs will be found in doc-types.sql

-- * type doc_refs

-- Type doc_refs represents hierarchical, versionable documents.

-- doc_refs documents may exist in different versions, represented
-- by multiple overlapping tree_doc_rows and changeset_doc_rows.

SELECT create_ref_type('doc_refs');

CREATE OR REPLACE
FUNCTION try_crefs_doc(crefs) RETURNS doc_refs
AS 'spx.so' LANGUAGE c;
COMMENT ON FUNCTION try_crefs_doc(crefs) IS
'returns the document of the tree node being rendered';

-- * key table and abstract base classes

CREATE TABLE IF NOT EXISTS doc_keys (
	key doc_refs PRIMARY KEY
);

SELECT create_handles_for('doc_keys');
SELECT create_key_trigger_functions_for('doc_keys');

CREATE TABLE IF NOT EXISTS abstract_doc_rows (
	ref doc_refs -- PRIMARY KEY REFERENCES doc_keys
);

COMMENT ON TABLE abstract_doc_rows IS
'Most doc_rows tables should probably inherit from
abstract_base_doc_rows instead of this base class!';

SELECT declare_abstract('abstract_doc_rows');
SELECT declare_ref_type_class('doc_refs', 'abstract_doc_rows'); -- why??

CREATE TABLE IF NOT EXISTS abstract_base_doc_rows (
	lang doc_lang_name_refs NOT NULL, -- REFERENCES doc_lang_name_rows
	page_uri_ page_uri_refs -- REFERENCES page_uri_rows
) INHERITS (abstract_doc_rows);
COMMENT ON COLUMN abstract_base_doc_rows.page_uri_ IS
'For document management purposes,
e.g. XFiles Domain Path document was loaded from,
typically but not necessarily the uri of a webpage.';

SELECT declare_abstract('abstract_base_doc_rows');
-- SELECT declare_ref_type_class('doc_refs', 'abstract_base_doc_rows'); -- why??

CREATE TABLE IF NOT EXISTS abstract_static_doc_rows (
	hash__ hashes,
	length__ bigint
) INHERITS (abstract_base_doc_rows);
COMMENT ON COLUMN abstract_static_doc_rows.hash__ IS
'If present, should be the md5 hash of the document contents.';
COMMENT ON COLUMN abstract_static_doc_rows.length__ IS
'If present, should be the byte count of the document contents.';

SELECT declare_abstract('abstract_static_doc_rows');
-- SELECT declare_ref_type_class('doc_refs', 'abstract_static_doc_rows'); -- why??

-- * id management

CREATE OR REPLACE
FUNCTION unchecked_ref_doc_from_class_id(regclass, ref_ids)
RETURNS doc_refs AS $$
	SELECT
		unchecked_ref('doc_refs', $1, $2)::doc_refs
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION doc_nil() RETURNS doc_refs AS $$
	SELECT unchecked_ref_doc_from_class_id('abstract_doc_rows', 0)
$$ LANGUAGE SQL IMMUTABLE;

INSERT INTO doc_keys VALUES ( doc_nil() );

DROP SEQUENCE IF EXISTS doc_id_seq CASCADE;

CREATE SEQUENCE doc_id_seq
	OWNED BY abstract_doc_rows.ref
	MINVALUE 1 MAXVALUE :RefIdMax CYCLE;

CREATE OR REPLACE
FUNCTION next_doc_ref(regclass) RETURNS doc_refs AS $$
	SELECT unchecked_ref_doc_from_class_id(
		$1, nextval('doc_id_seq')::ref_ids
	)
$$ LANGUAGE SQL;

-- * Concrete Classes

CREATE TABLE IF NOT EXISTS tree_doc_rows (
	PRIMARY KEY (ref),
	FOREIGN KEY(ref) REFERENCES doc_keys ON DELETE CASCADE,
	FOREIGN KEY(lang) REFERENCES doc_lang_name_rows,
	root doc_node_refs UNIQUE NOT NULL
		REFERENCES doc_node_keys
) INHERITS(abstract_base_doc_rows);
COMMENT ON TABLE tree_doc_rows IS
'tree_doc_rows represents a document comprising a complete
tree structure starting with a given root node.';

SELECT declare_ref_class('tree_doc_rows');

ALTER TABLE tree_doc_rows ALTER COLUMN ref
	SET DEFAULT next_doc_ref( 'tree_doc_rows' );

SELECT create_key_triggers_for('tree_doc_rows', 'doc_keys');

CREATE TABLE IF NOT EXISTS changeset_doc_rows (
	PRIMARY KEY (ref),
	FOREIGN KEY(ref) REFERENCES doc_keys ON DELETE CASCADE,
	base doc_refs NOT NULL REFERENCES doc_keys ON DELETE CASCADE,
	grafts doc_node_refs[]
		NOT NULL -- ELEMENTS_REFERENCE doc_node_keys
--   , CONSTRAINT changeset_docs_grafts_are_grafts
--     CHECK( is_array_ref_of(graft_node_tag(), grafts) )
--   ,
--   CONSTRAINT changeset_docs_grafts_are_unique
--     CHECK( graft_array_is_unique(grafts) )
) INHERITS(abstract_doc_rows);
COMMENT ON TABLE changeset_doc_rows IS
'Expresses the same content as the base document except
with any nodes (or other refs???) occurring in the base document
being replaced on-the-fly by the grafts which reference them.
Do we need changeset_doc_rows to be unique???';
COMMENT ON COLUMN changeset_doc_rows.base IS
'This ref should be associated with a single document - webpage,
css page, javascript page, etc.  All doc_nodes reachable by
traversing that document, and their replacement doc_nodes
should be expressing the content of the same base document.';

SELECT declare_ref_class('changeset_doc_rows');

ALTER TABLE changeset_doc_rows ALTER COLUMN ref
	SET DEFAULT next_doc_ref( 'changeset_doc_rows' );

SELECT create_key_triggers_for('changeset_doc_rows', 'doc_keys');

-- blob_doc_rows

CREATE TABLE IF NOT EXISTS blob_doc_rows (
	PRIMARY KEY (ref),
	FOREIGN KEY(lang) REFERENCES doc_lang_name_rows,
	blob_ blob_refs NOT NULL REFERENCES blob_rows
) INHERITS(abstract_static_doc_rows);
COMMENT ON TABLE blob_doc_rows IS
'Represents a possibly large, possibly binary sequence of
bytes which will be given to clients as one or more chunks of
type bytea, along with the associated lang.  Clients, e.g. a
Wicci Shim are responsble for correctly interpreting the bytes.
We can accurately tell them the size of the blob.';

SELECT declare_ref_class('blob_doc_rows');

ALTER TABLE blob_doc_rows ALTER COLUMN ref
	SET DEFAULT next_doc_ref( 'blob_doc_rows' );

SELECT create_key_triggers_for('blob_doc_rows', 'doc_keys');

-- file_doc_rows

CREATE TABLE IF NOT EXISTS file_doc_rows (
	PRIMARY KEY (ref),
	FOREIGN KEY(lang) REFERENCES doc_lang_name_rows,
	FOREIGN KEY(page_uri_) REFERENCES page_uri_rows
) INHERITS(abstract_static_doc_rows);
COMMENT ON TABLE file_doc_rows IS
'Represents a possibly large, possibly binary sequence of
bytes which will be given to clients as one or more chunks of
type bytea, along with the associated lang.  Clients, e.g. a
Wicci Shim are responsble for correctly interpreting the bytes.';

SELECT declare_ref_class('file_doc_rows');

ALTER TABLE file_doc_rows ALTER COLUMN ref
	SET DEFAULT next_doc_ref( 'file_doc_rows' );

SELECT create_key_triggers_for('file_doc_rows', 'doc_keys');

-- large_object_doc_rows

CREATE TABLE IF NOT EXISTS large_object_doc_rows (
	PRIMARY KEY (ref),
	FOREIGN KEY(lang) REFERENCES doc_lang_name_rows,
	oid oid NOT NULL
) INHERITS(abstract_static_doc_rows);
COMMENT ON TABLE large_object_doc_rows IS
'Represents a possibly large, possibly binary sequence of
bytes which must be accessed by clients using PostgreSQL''s
large object API using the oid.  Clients will also be given
the lang so they will know how to interpret the bytes.';

SELECT declare_ref_class('large_object_doc_rows');

ALTER TABLE large_object_doc_rows ALTER COLUMN ref
	SET DEFAULT next_doc_ref( 'large_object_doc_rows' );

SELECT create_key_triggers_for('large_object_doc_rows', 'doc_keys');

-- * static_doc_storage_policy

CREATE OR REPLACE
FUNCTION static_doc_storage_policy()
RETURNS regclass AS $$
	SELECT 'file_doc_rows'::regclass
$$ LANGUAGE SQL;
