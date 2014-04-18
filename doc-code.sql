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

-- * env_doc

SELECT create_env_name_type_func(
	'env_doc', 'doc_refs'
);
