-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('doc-node-code.sql', '$Id');

--	Wicci Project
--	ref type doc_node_refs (tree of refs) code

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * Magic implemented in C:

CREATE OR REPLACE
FUNCTION ref_crefs_graft(refs, crefs) RETURNS doc_node_refs
AS 'spx.so' LANGUAGE c;
COMMENT ON FUNCTION ref_crefs_graft(refs, crefs)
IS 'wicci magic check for tree node substitution;
WARNING: does not currently check that the result
really is a tree node!!';

-- ** doc_node_init() -> cstring

-- subsumed in doc_init

-- Moved to ???-node-schema:
-- FUNCTION tree_nodes_parent(doc_node_refs[]) RETURNS doc_node_refs

-- ** doc_node_nil

CREATE OR REPLACE
FUNCTION nil_doc_node_text(doc_node_refs) RETURNS TEXT AS $$
	SELECT '(doc_node_refs ' || $1::text || ')'
$$ LANGUAGE sql;

SELECT type_class_out(
	'doc_node_refs', 'abstract_doc_node_rows',
	'nil_doc_node_text(doc_node_refs)'
);

SELECT type_class_op_method(
	'doc_node_refs', 'abstract_doc_node_rows',
	'ref_text_op(refs)', 'nil_doc_node_text(doc_node_refs)'
);

-- * TABLE tree_doc_node_rows OR TABLE graft_doc_node_rows

CREATE OR REPLACE FUNCTION doc_node_text(
	doc_node_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS TEXT AS $$
	SELECT CASE ref_table($1)
		WHEN 'tree_doc_node_rows'::regclass THEN (
			SELECT ref_env_crefs_chiln_text_op(kind, $2, $3, children)
			FROM tree_doc_node_rows WHERE ref = $1
		)
		WHEN 'graft_doc_node_rows'::regclass THEN (
			SELECT ref_env_crefs_chiln_text_op(kind, $2, $3, children)
			FROM graft_doc_node_rows WHERE ref = $1
		)
		ELSE case_failed_any_ref(
			this, NULL::text, $1
		)
	END FROM debug_enter(
		'doc_node_text(doc_node_refs, env_refs, crefs)', show_ref($1)
	) this
$$ LANGUAGE sql;
COMMENT ON FUNCTION doc_node_text(doc_node_refs, env_refs, crefs)
IS 'produce text from a tree or graft node';

CREATE OR REPLACE
FUNCTION show_ref(doc_node_refs, text=NULL) RETURNS TEXT AS $$
	SELECT COALESCE($2 || ': ', '') || CASE ref_table($1)
		WHEN 'tree_doc_node_rows'::regclass THEN (
			SELECT ref_env_crefs_chiln_text_op(
				kind, env_nil(), crefs_nil(), '{}'
			) FROM tree_doc_node_rows WHERE ref = $1
		)
		WHEN 'graft_doc_node_rows'::regclass THEN (
			SELECT ref_env_crefs_chiln_text_op(
				kind, env_nil(), crefs_nil(), '{}'
			) FROM graft_doc_node_rows WHERE ref = $1
		)
		ELSE show_ref($1::refs)
	END
$$ LANGUAGE sql;

-- ** convenience selection functions

CREATE OR REPLACE
FUNCTION graft_doc_node_origin(doc_node_refs)
RETURNS doc_node_refs AS $$
	SELECT origin FROM graft_doc_node_rows WHERE ref=$1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION tree_doc_node_parent(doc_node_refs)
RETURNS doc_node_refs AS $$
	SELECT parent FROM doc_node_parents WHERE child=$1
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION doc_node_parent(doc_node_refs)
RETURNS doc_node_refs AS $$
	SELECT CASE ref_table($1)
		WHEN 'tree_doc_node_rows'::regclass
			THEN tree_doc_node_parent($1)
		WHEN 'graft_doc_node_rows'::regclass
			THEN tree_doc_node_parent(graft_doc_node_origin($1))
		ELSE case_failed_any_ref( 'doc_node_parent(doc_node_refs)', $1, $1 )
	END
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION doc_node_kind(doc_node_refs) RETURNS doc_node_kind_refs AS $$
	SELECT CASE ref_table($1)
		WHEN 'tree_doc_node_rows'::regclass THEN (
			SELECT kind FROM tree_doc_node_rows WHERE ref = $1
		)
		WHEN 'graft_doc_node_rows'::regclass THEN (
			SELECT kind FROM graft_doc_node_rows WHERE ref = $1
		)
		ELSE case_failed_any_ref(
			'doc_node_kind(doc_node_refs)',
--			unchecked_ref_null()::doc_node_kind_refs, $1
			NULL::doc_node_kind_refs, $1
		)
	END
$$ LANGUAGE sql;
COMMENT ON FUNCTION doc_node_kind(doc_node_refs)
IS 'fetch the kind from a tree or graft node';

-- * TABLE tree_doc_node_rows

-- wrong??? revisit!!!
CREATE OR REPLACE FUNCTION tree_node_text(
	doc_node_refs,  env_refs = env_nil(),  crefs = crefs_nil()
) RETURNS TEXT AS $$
	SELECT doc_node_text(
		COALESCE( ref_crefs_graft($1, $3), $1 ),
		$2, $3
	)
$$ LANGUAGE sql;
COMMENT ON FUNCTION tree_node_text(doc_node_refs, env_refs, crefs)
IS 'produce text from a tree node';

--  new_tree_node(kind, children)
CREATE OR REPLACE FUNCTION new_tree_node(
	doc_node_kind_refs,
	VARIADIC doc_node_refs[] = no_doc_node_children()
) RETURNS doc_node_refs AS $$
	INSERT INTO tree_doc_node_rows(kind, children) VALUES ($1, $2)
	RETURNING ref
$$ LANGUAGE sql;
COMMENT ON FUNCTION  new_tree_node(doc_node_kind_refs, doc_node_refs[]) IS '
	Creates new tree_doc_node_rows row.
	Could use a special ref_leaves table for efficency.
	tree_doc_node_rows rows are NOT findable by their data!!!
	You must find them by their location in the tree_parents table!!
';

-- ** find_by_path

CREATE OR REPLACE
FUNCTION match_grafts_first_(doc_node_refs, grafts doc_node_refs[])
RETURNS doc_node_refs AS $$
	SELECT COALESCE(
		( SELECT ref FROM graft_doc_node_rows
			WHERE $1 = origin AND ref = ANY($2)
			LIMIT 1
		),
		$1
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION
match_grafts_first_(doc_node_refs, grafts doc_node_refs[])
IS 'Returns the subset of $2 which have $1 as their doc_node origin';

CREATE OR REPLACE
FUNCTION match_grafts_left_(doc_node_refs, grafts doc_node_refs[])
RETURNS doc_node_refs[] AS $$
	SELECT ARRAY(
		SELECT ref FROM graft_doc_node_rows WHERE $1 <> origin AND ref = ANY($2)
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION
match_grafts_left_(doc_node_refs, grafts doc_node_refs[])
IS 'Returns the subset of $2 which does NOT have $1 as their doc_node origin';

-- for efficiency, match_grafts_first_ and match_grafts_left_ could be
-- combined into one search - is it worth it??

CREATE OR REPLACE FUNCTION find_by_path(
	doc_node_refs, path integer[], grafts doc_node_refs[] = no_doc_node_array()
) RETURNS doc_node_refs AS $$
	SELECT CASE
		WHEN is_nil(node) THEN node
		WHEN array_is_empty($2) THEN node
		ELSE ( SELECT
				find_by_path(children[array_head($2)], array_tail($2), match_grafts_left_($1, $3))
			FROM abstract_doc_node_rows WHERE ref = $1
		)
	END
	FROM match_grafts_first_($1, $3) node
$$ LANGUAGE sql;

-- * TABLE graft_doc_node_rows

CREATE OR REPLACE
FUNCTION graft_node_old_array(doc_node_refs[]) RETURNS refs[] AS $$
	SELECT ARRAY(
		SELECT origin::refs
		FROM unnest($1) g, graft_doc_node_rows WHERE g = ref
	)
$$ LANGUAGE sql;
COMMENT ON FUNCTION graft_node_old_array(doc_node_refs[])
IS 'return the grafts array as a ref array';

CREATE OR REPLACE
FUNCTION graft_node_new_array(doc_node_refs[]) RETURNS refs[] AS $$
	SELECT ARRAY(
		SELECT g::refs
		FROM unnest($1) g, graft_doc_node_rows WHERE g = ref
	)
$$ LANGUAGE sql;
COMMENT ON FUNCTION graft_node_new_array(doc_node_refs[])
IS 'return the grafts array as a ref array';

CREATE OR REPLACE FUNCTION graft_node_text(
	doc_node_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS TEXT AS $$
	SELECT doc_node_text(
		COALESCE( ref_crefs_graft(origin, $3), $1 ), $2, $3
	) FROM graft_doc_node_rows WHERE ref = $1
$$ LANGUAGE sql;
COMMENT ON FUNCTION graft_node_text(doc_node_refs, env_refs, crefs)
IS 'produce text from a graft node';

-- find_ref_graft_node(old doc_node_refs, kind, children)
CREATE OR REPLACE
FUNCTION find_ref_graft_node(doc_node_refs, doc_node_kind_refs, doc_node_refs[])
RETURNS doc_node_refs AS $$
	SELECT ref FROM graft_doc_node_rows
	WHERE origin = $1 AND kind = $2 AND children = $3
$$ LANGUAGE sql STRICT;

-- make_ref_graft_node(old doc_node_refs, kind, children)
CREATE OR REPLACE
FUNCTION make_ref_graft_node(doc_node_refs, doc_node_kind_refs, doc_node_refs[])
RETURNS doc_node_refs AS $$
	DECLARE
		the_ref doc_node_refs := NULL; -- unchecked_ref_null();
		kilroy_was_here boolean := false;
		this regprocedure
			:= 'make_ref_graft_node(doc_node_refs, doc_node_kind_refs, doc_node_refs[])';
	BEGIN
		LOOP
			SELECT ref INTO the_ref FROM graft_doc_node_rows
			WHERE origin = $1 AND kind = $2 AND children = $3;
			IF FOUND THEN
				RETURN the_ref;
			END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % % %', this, $1, $2, $3;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO graft_doc_node_rows(origin, kind, children)
				VALUES ($1, $2, $3);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % % raised %!',
					this, $1, $2, $3, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

-- graft_node(old, kind, children)
CREATE OR REPLACE
FUNCTION try_graft_node(doc_node_refs, doc_node_kind_refs,
	VARIADIC doc_node_refs[] = no_doc_node_children() 
) RETURNS doc_node_refs AS $$
	SELECT COALESCE(
		find_ref_graft_node($1, $2, $3),
		make_ref_graft_node($1, $2, $3)
	)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION graft_node(
	doc_node_refs, doc_node_kind_refs,
	VARIADIC doc_node_refs[] = no_doc_node_children()
) RETURNS doc_node_refs AS $$
	SELECT non_null(
		try_graft_node($1, $2,VARIADIC $3),
		'graft_node(doc_node_refs,doc_node_kind_refs,doc_node_refs[])'
	)
$$ LANGUAGE sql;

COMMENT ON
FUNCTION graft_node(doc_node_refs, doc_node_kind_refs, doc_node_refs[])
IS 'alternate doc_node_refs with different kind and/or children';

-- * id_to_xml functions

-- see xml-output-code.sql section * TYPE doc_node_refs

-- SELECT type_class_out(
-- 	'doc_node_refs', 'graft_doc_node_rows',
-- 	'graft_node_text(doc_node_refs, env_refs, crefs)'
-- );

SELECT type_class_op_method(
	'doc_node_refs', 'graft_doc_node_rows',
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'graft_node_text(doc_node_refs, env_refs, crefs)'
);

-- SELECT type_class_out(
-- 	'doc_node_refs', 'tree_doc_node_rows',
-- 	'tree_node_text(doc_node_refs, env_refs, crefs)'
-- );

SELECT type_class_op_method(
	'doc_node_refs', 'tree_doc_node_rows',
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'tree_node_text(doc_node_refs, env_refs, crefs)'
);
