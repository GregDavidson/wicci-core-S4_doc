-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('doc-kind-schema.sql', '$Id');

--	Wicci Project
--	doc_node_kinds -- the kinds of data of document nodes

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * type doc_node_kind_refs

SELECT create_ref_type('doc_node_kind_refs');

-- Type doc_node_kind_refs represents the kind of a doc_node_refs.

-- It's not yet clear that we actually need a separate type for this
-- purpose, although it is at least valuable conceptually.

-- * key table and abstract base classes

CREATE TABLE IF NOT EXISTS doc_node_kind_keys (
	key doc_node_kind_refs PRIMARY KEY
);

SELECT create_handles_for('doc_node_kind_keys');
SELECT create_key_trigger_functions_for('doc_node_kind_keys');

CREATE TABLE IF NOT EXISTS abstract_doc_node_kind_rows (
	ref doc_node_kind_refs --  PRIMARY KEY
);
COMMENT ON TABLE abstract_doc_node_kind_rows IS
'The base class of those classes which label the nodes of
hierarchical structures and direct how those nodes participate
in operations.
Abstract ref kinds (ids with no corresponding tuples) are allocated
from the same sequence as this table, and this table is used as
the associated table in typed_object_classes.';

SELECT declare_abstract('abstract_doc_node_kind_rows');

SELECT declare_ref_type_class(
	'doc_node_kind_refs', 'abstract_doc_node_kind_rows'
);

-- * id management

CREATE OR REPLACE
FUNCTION unchecked_doc_node_kind_from_class_id(regclass, ref_ids)
RETURNS doc_node_kind_refs AS $$
	SELECT unchecked_ref(
		'doc_node_kind_refs', $1, $2
	)::doc_node_kind_refs
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION doc_node_kind_nil() RETURNS doc_node_kind_refs AS $$
	SELECT unchecked_doc_node_kind_from_class_id(
		'abstract_doc_node_kind_rows', 0
	)
$$ LANGUAGE SQL IMMUTABLE;

DROP SEQUENCE IF EXISTS doc_kinds_id_seq CASCADE;

CREATE SEQUENCE doc_kinds_id_seq
			 OWNED BY abstract_doc_node_kind_rows.ref
	MINVALUE 1 MAXVALUE :RefIdMax CYCLE;

CREATE OR REPLACE
FUNCTION next_doc_node_kind(regclass)
RETURNS doc_node_kind_refs AS $$
	SELECT unchecked_doc_node_kind_from_class_id(
		$1, nextval('doc_kinds_id_seq')::ref_ids
	)
$$ LANGUAGE SQL;

-- ** Special Initial Values

-- * Concrete Classes

-- ** TABLE show1_doc_node_kind_rows

CREATE TABLE IF NOT EXISTS show1_doc_node_kind_rows (
	PRIMARY KEY (ref),
	val refs
) INHERITS(abstract_doc_node_kind_rows);
COMMENT ON TABLE show1_doc_node_kind_rows IS
'show1_doc_node_kind_rows shows the structure of a tree with
the val on a line by itself followed by the children
indented; the indent level needs to be specified in the
environment';

SELECT declare_ref_class('show1_doc_node_kind_rows');
SELECT
	declare_doc_kind_lang_type('show1_doc_node_kind_rows', 'show1');

ALTER TABLE show1_doc_node_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'show1_doc_node_kind_rows' );

SELECT create_key_triggers_for(
	'show1_doc_node_kind_rows', 'doc_node_kind_keys'
);

-- ** TABLE env_wrap_doc_node_kind_rows
CREATE TABLE IF NOT EXISTS env_wrap_doc_node_kind_rows (
	PRIMARY KEY (ref),
	before_ env_refs,
	after_ env_refs,
	node_ doc_node_kind_refs			-- s/node_/kind_/ ???
) INHERITS(abstract_doc_node_kind_rows);
COMMENT ON TABLE env_wrap_doc_node_kind_rows IS '
	Represents the xml text of node rendered in
	an augmennted environment context.  See the
	text method for env_wrap_doc_node_kind_rows!
';

SELECT declare_ref_class('env_wrap_doc_node_kind_rows');

ALTER TABLE env_wrap_doc_node_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'env_wrap_doc_node_kind_rows' );

SELECT create_key_triggers_for(
	'env_wrap_doc_node_kind_rows', 'doc_node_kind_keys'
);

-- * Dynamic Kinds

CREATE TABLE IF NOT EXISTS dynamic_doc_node_kind_rows (
	PRIMARY KEY (ref),
	name_ text UNIQUE NOT NULL
) INHERITS(abstract_doc_node_kind_rows);
COMMENT ON TABLE dynamic_doc_node_kind_rows IS '
	Each row is an attachment point for kind methods.
	Some C magic will be needed to make this work efficiently.
';

SELECT declare_ref_class('dynamic_doc_node_kind_rows');

ALTER TABLE dynamic_doc_node_kind_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node_kind( 'dynamic_doc_node_kind_rows' );

SELECT create_key_triggers_for(
	'dynamic_doc_node_kind_rows', 'doc_node_kind_keys'
);

CREATE TABLE IF NOT EXISTS dynamic_kind_methods (
	kind_ doc_node_kind_refs NOT NULL
	REFERENCES dynamic_doc_node_kind_rows ON DELETE CASCADE,
	operation_ regprocedure NOT NULL
	REFERENCES our_procs ON DELETE CASCADE,
	method_ regprocedure NOT NULL
	REFERENCES our_procs ON DELETE CASCADE,
	PRIMARY KEY(kind_, operation_)
);
COMMENT ON TABLE dynamic_kind_methods IS '
	Each row binds a method to an operation
	for a specific doc_node_kind_refs reference.
	Some C magic will be needed to make this work efficiently.
';

-- * Blob Kinds

-- We no longer have Blob Kinds, although we have
-- Blob Documents.  We also have Blobs defined
-- in text-ref-schema.sql which are available if
-- we ever need to recreate Blob Kinds!
