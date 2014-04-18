-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('tor2-node-schema.sql', '$Id');

--	Wicci Project
--	ref type doc_node_refs (tree of refs) schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * type doc_node_refs introduction

-- This type exists to represent nodes of hierarchically-structured
-- versionable documents, such as html (and other xml family) documents,
-- CSS, JavaScript (and other tree-structured languages), etc.

-- It's not yet clear that we actually need a separate type for this
-- purpose, although it is at least valuable conceptually.

-- * TYPE doc_node_refs

SELECT create_ref_type('doc_node_refs');

-- * key table and abstract base classes

CREATE TABLE IF NOT EXISTS doc_node_keys (
	key doc_node_refs PRIMARY KEY
);

SELECT create_handles_for('doc_node_keys');
SELECT create_key_trigger_functions_for('doc_node_keys');

CREATE TABLE IF NOT EXISTS abstract_doc_node_rows (
	ref doc_node_refs, --  PRIMARY KEY,
	kind doc_node_kind_refs NOT NULL,           -- check signature of to_text method???
	children doc_node_refs[] NOT NULL
);
COMMENT ON TABLE abstract_doc_node_rows IS
'The base class for tree and graft nodes.  The ref should be unique
within and across documents.  The kind tells us how to render';
COMMENT ON COLUMN abstract_doc_node_rows.kind IS
'An object which provides structure for this node, e.g.
xml_elements, xml_literals, etc.  I''s true type depends on the
document type, which is beyond pg''s type checking.  We could check
it dynamically and/or check and see if its to_text method has an
appropriate signature.  It would be better if it had type doc_node_kind_refs!!!';
COMMENT ON COLUMN abstract_doc_node_rows.children IS
'Alternatives:
(1) Store the first child and the next sibling.
(2) Use four tables for the cases of have_children X have_next_sibling.
(3) Just use the doc_node_parents association table.';

SELECT declare_abstract('abstract_doc_node_rows');
SELECT declare_ref_type_class('doc_node_refs', 'abstract_doc_node_rows');

-- * id management

CREATE OR REPLACE
FUNCTION unchecked_doc_node_from_class_id(regclass, ref_ids)
RETURNS doc_node_refs AS $$
	SELECT unchecked_ref('doc_node_refs', $1, $2)::doc_node_refs
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION doc_node_nil() RETURNS doc_node_refs AS $$
	SELECT unchecked_doc_node_from_class_id('abstract_doc_node_rows', 0)
$$ LANGUAGE SQL IMMUTABLE;

DROP SEQUENCE IF EXISTS doc_node_id_seq CASCADE;

CREATE SEQUENCE doc_node_id_seq
	OWNED BY abstract_doc_node_rows.ref
	MINVALUE 1 MAXVALUE :RefIdMax CYCLE;

CREATE OR REPLACE
FUNCTION next_doc_node(regclass) RETURNS doc_node_refs AS $$
	SELECT unchecked_doc_node_from_class_id(
		$1, nextval('doc_node_id_seq')::ref_ids
	)
$$ LANGUAGE SQL;

-- ** Special Initial Values

CREATE OR REPLACE
FUNCTION no_doc_node_array() RETURNS doc_node_refs[] AS $$
	SELECT '{}'::doc_node_refs[] -- empty array
$$ LANGUAGE SQL;
COMMENT ON FUNCTION no_doc_node_array() IS 'an empty array';

CREATE OR REPLACE
FUNCTION no_doc_node_children() RETURNS doc_node_refs[] AS $$
	SELECT no_doc_node_array()
$$ LANGUAGE SQL;
COMMENT ON FUNCTION no_doc_node_children() IS
'an empty array indicating no children';

CREATE OR REPLACE
FUNCTION no_doc_node_siblings() RETURNS doc_node_refs[] AS $$
	SELECT no_doc_node_array()
$$ LANGUAGE SQL;
COMMENT ON FUNCTION no_doc_node_siblings() IS
'an empty array indicating no siblings';

-- ** Concrete Classes

-- ** TABLEs graft_doc_node_rows

CREATE TABLE IF NOT EXISTS graft_doc_node_rows (
	PRIMARY KEY (ref),
	origin doc_node_refs
) INHERITS(abstract_doc_node_rows);
COMMENT ON TABLE graft_doc_node_rows IS '
	A replacement for a doc_node_refs;
	the root of a tree of graft_doc_node_rows must be
	reachable from a changeset  doc.
';
COMMENT ON COLUMN graft_doc_node_rows.origin IS '
	The origin place of this node represented by the
	ref of a tree node.
';

SELECT
	create_key_triggers_for('graft_doc_node_rows', 'doc_node_keys');
SELECT declare_ref_class('graft_doc_node_rows');

ALTER TABLE graft_doc_node_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node( 'graft_doc_node_rows' );

ALTER TABLE graft_doc_node_rows ADD
CONSTRAINT graft_nodes_ref_class
CHECK(ref_table(ref) = 'graft_doc_node_rows'::regclass);

-- ** TABLE tree_doc_node_rows

CREATE TABLE IF NOT EXISTS tree_doc_node_rows (
	PRIMARY KEY (ref)
) INHERITS(abstract_doc_node_rows);
COMMENT ON TABLE tree_doc_node_rows IS
'A tree node in a doc_refs.  The parent and slot give it a specific
location in a specific place in its document.  We may need a
tree_nodes_non_cyclical constraint.  There are still unresolved
issues of uniqueness.';

SELECT declare_ref_class('tree_doc_node_rows');
SELECT
	create_key_triggers_for('tree_doc_node_rows', 'doc_node_keys');

ALTER TABLE tree_doc_node_rows ALTER COLUMN ref
	SET DEFAULT next_doc_node( 'tree_doc_node_rows' );

ALTER TABLE tree_doc_node_rows ADD
CONSTRAINT tree_nodes_ref_class
CHECK(ref_table(ref) = 'tree_doc_node_rows'::regclass);

-- ** TABLE doc_node_parents

CREATE TABLE IF NOT EXISTS doc_node_parents (
	parent doc_node_refs NOT NULL
		REFERENCES doc_node_keys ON DELETE CASCADE,
	slot INTEGER NOT NULL CHECK(slot > 0),
	child doc_node_refs NOT NULL
		REFERENCES tree_doc_node_rows ON DELETE CASCADE,
	UNIQUE(parent, slot, child)
);
COMMENT ON TABLE doc_node_parents IS
'Associates tree_doc_node_rows with their parents and their index slot.
Maintained by triggers. Questions:
(1) Do we actually use this table?
(2) Should we use two tables,
one for tree parents, one for graft parents?
(3) Should we record the "orginal" parent rather
than the graft parent, in this or another table, so
that we can eliminate duplicates???
';

CREATE OR REPLACE
FUNCTION is_doc_node_root(doc_node_refs) RETURNS boolean AS $$
	SELECT CASE ref_table($1)
		WHEN 'tree_doc_node_rows'::regclass THEN NOT EXISTS (
			SELECT parent FROM doc_node_parents WHERE parent = $1
		)
		WHEN 'graft_doc_node_rows'::regclass THEN (
			SELECT is_doc_node_root(origin)
			FROM graft_doc_node_rows WHERE ref = $1
		)
		ELSE case_failed_any_ref(
			'is_doc_node_root(doc_node_refs)', false, $1
		)
	END
$$ LANGUAGE SQL;

 -- create associated doc_node_parents entries for our children
CREATE OR REPLACE
FUNCTION doc_nodes_after_inserter() RETURNS trigger AS $$
	DECLARE
		i INTEGER;
	BEGIN
		IF array_lower(NEW.children,1) IS NOT NULL THEN
			FOR i IN
				array_lower(NEW.children,1)..array_upper(NEW.children,1)
			LOOP
				INSERT INTO doc_node_parents(parent, slot, child)
					VALUES(NEW.ref, i, NEW.children[i]);
			END LOOP;
		END IF;
		RETURN NEW;			-- ignored since is an after trigger
	END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION doc_nodes_after_inserter() IS
'creates doc_node_parents rows corresponding to children';

DROP TRIGGER IF EXISTS doc_nodes_after_inserter
	ON doc_node_parents CASCADE;

CREATE TRIGGER tree_nodes_after_inserter
	AFTER INSERT ON tree_doc_node_rows
	FOR EACH ROW EXECUTE PROCEDURE doc_nodes_after_inserter();

CREATE TRIGGER graft_nodes_after_inserter
	AFTER INSERT ON graft_doc_node_rows
	FOR EACH ROW EXECUTE PROCEDURE doc_nodes_after_inserter();
