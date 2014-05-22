-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('tor2-kind-code.sql', '$Id');

--	Wicci Project
--	ref type doc_node_kind_refs  code

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * Operators

-- oftd !!!
CREATE OR REPLACE FUNCTION oftd_ref_env_crefs_chiln_text_op(
	regprocedure, refs[], refs[], refs,
	refs, env_refs, crefs, doc_node_refs[]
) RETURNS text AS 'spx.so', 'oftd_ref_env_crefs_etc_text_op'
LANGUAGE c;

-- s/refs/doc_node_kind_refs/ when same for type of doc_nodes.kind !! ??
CREATE OR REPLACE FUNCTION ref_env_crefs_chiln_text_op(
	refs, env_refs, crefs, doc_node_refs[]
) RETURNS text AS 'spx.so', 'ref_env_crefs_etc_text_op'
 LANGUAGE c;

CREATE OR REPLACE FUNCTION try_show_ref_env_crefs_chiln(
	refs, env_refs=env_nil(), crefs=crefs_nil(),
	doc_node_refs[]='{}', ref_tags=NULL
) RETURNS text AS $$
	SELECT ref_env_crefs_chiln_text_op($1, $2, $3, $4)
	FROM typed_object_methods
	WHERE tag_ = COALESCE($5, ref_tag($1))
	AND operation_ = this( 'ref_env_crefs_chiln_text_op(
		refs, env_refs, crefs, doc_node_refs[]
	)' )
$$ LANGUAGE sql;

SELECT declare_op_fallback(
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
	'ref_env_crefs_text_op(refs, env_refs, crefs)'
);

CREATE OR REPLACE
FUNCTION show_ref(refs, text=NULL) RETURNS text AS $$
	SELECT COALESCE($2 || ': ', '') || COALESCE(
		try_show_ref($1, _tag),
		try_show_ref_env($1, env_nil(), _tag),
		try_show_ref_env_crefs($1, env_nil(), crefs_nil(), _tag),
		try_show_ref_env_crefs_chiln(
			$1, env_nil(), crefs_nil(), '{}', _tag
		),
		ref_textout($1)
	) FROM ref_tag($1) _tag;
$$ LANGUAGE sql;


-- * Methods

-- ** show1_kind

SELECT declare_name('indent', '');

-- should indent map to a int_refs??
-- should indentation be automagically in the crefs??
-- _chiln_text ??
CREATE OR REPLACE FUNCTION show1_kind_text(
	doc_node_kind_refs, env_refs = env_nil(), crefs = crefs_nil(),
	chiln doc_node_refs[] = no_doc_node_array()
) RETURNS TEXT AS $$
DECLARE
	nl_indent text := E'\n'::text || xml_indent(crefs_indent($3));
	new_env env_refs := NULL; -- unchecked_ref_null();
	this_text text;
	child_texts text[] := NULL;
BEGIN
	SELECT ref_env_crefs_text_op(val, $2, $3) INTO this_text
	FROM show1_doc_node_kind_rows WHERE ref = $1;
	IF $4 IS NOT NULL THEN
		SELECT ARRAY(
			SELECT ref_env_crefs_text_op(x, $2, $3)
			FROM unnest($4) x
		) INTO child_texts;
	END IF;
	IF array_is_empty(child_texts) THEN
		RETURN this_text;
	ELSE
		RETURN this_text || nl_indent
	|| array_to_string(child_texts, nl_indent);
	END IF;
END
$$ LANGUAGE 'plpgsql';
COMMENT ON
FUNCTION show1_kind_text(
	doc_node_kind_refs, env_refs, crefs, doc_node_refs[]
) IS 'show1 structure of tree with node ids and parentheses';

SELECT type_class_op_method(
	'doc_node_kind_refs', 'show1_doc_node_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
'show1_kind_text(doc_node_kind_refs,env_refs,crefs,doc_node_refs[])'
);

CREATE OR REPLACE
FUNCTION find_show1_kind(refs) RETURNS doc_node_kind_refs AS $$
	SELECT ref FROM show1_doc_node_kind_rows WHERE val = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION make_show1_kind(doc_node_kind_refs, refs)
RETURNS doc_node_kind_refs AS $$
	INSERT INTO show1_doc_node_kind_rows(ref, val) VALUES($1, $2)
	RETURNING ref
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION make_show1_kind(refs)
RETURNS doc_node_kind_refs AS $$
	SELECT make_show1_kind(
		next_doc_node_kind('show1_doc_node_kind_rows'), $1
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION show1_kind(refs) RETURNS doc_node_kind_refs AS $$
	SELECT COALESCE(
		find_show1_kind($1),  make_show1_kind($1)
	)
$$ LANGUAGE SQL;

-- * Dynamic Kinds

CREATE OR REPLACE
FUNCTION try_dynamic_doc_node_kind(text) 
RETURNS doc_node_kind_refs AS $$
	SELECT ref FROM dynamic_doc_node_kind_rows WHERE name_=$1
$$ LANGUAGE sql STABLE STRICT;

CREATE OR REPLACE
FUNCTION find_dynamic_doc_node_kind(text)
RETURNS doc_node_kind_refs AS $$
	SELECT non_null(
		try_dynamic_doc_node_kind($1),
		'find_dynamic_doc_node_kind(text)', $1
	)
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION try_dynamic_kind_method(
	doc_node_kind_refs, regprocedure
)  RETURNS regprocedure AS $$
	SELECT method_ FROM dynamic_kind_methods
	WHERE kind_ = $1 AND operation_ = $2
$$ LANGUAGE sql STABLE STRICT;

CREATE OR REPLACE FUNCTION find_dynamic_kind_method(
	doc_node_kind_refs, regprocedure
) RETURNS regprocedure AS $$
	SELECT non_null(
		try_dynamic_kind_method($1,$2),
		'find_dynamic_kind_method(doc_node_kind_refs,regprocedure)',
		$2::text
	)
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION dynamic_kind_text(
	doc_node_kind_refs, env_refs = env_nil(), crefs = crefs_nil(),
	chiln doc_node_refs[] = '{}'
) RETURNS TEXT AS $$
DECLARE
	this regprocedure := 'dynamic_kind_text(
		doc_node_kind_refs, env_refs, crefs, doc_node_refs[]
	)';
	op regprocedure := 'ref_env_crefs_chiln_text_op(
		refs, env_refs, crefs, doc_node_refs[]
	)';
	method regprocedure := find_dynamic_kind_method($1, op);
	fname name;
	result text;
BEGIN
--	Which of these approaches is more efficient?
--	EXECUTE format('SELECT %I($1,$2,$3,$4)', method::regproc::text)
	SELECT INTO fname proname FROM pg_proc WHERE oid = method;
	EXECUTE format('SELECT %I($1,$2,$3,$4)', fname)
	INTO RESULT USING $1, $2, $3, $4;
	RETURN result;
END
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION dynamic_kind_text(
	doc_node_kind_refs, env_refs, crefs,chiln doc_node_refs[]
) IS '
	Dynamically execute the appropriate method
	for this operation applied to this kind..
	This should be done in C with saved query plans
	to be at all efficient!!
';

SELECT type_class_op_method(
	'doc_node_kind_refs', 'dynamic_doc_node_kind_rows',
	'ref_env_crefs_chiln_text_op(refs, env_refs, crefs, doc_node_refs[])',
'dynamic_kind_text(doc_node_kind_refs,env_refs,crefs,doc_node_refs[])'
);

-- * meta-code for "special" classes

CREATE OR REPLACE
FUNCTION create_dynamic_kind(text)
RETURNS doc_node_kind_refs AS $$
DECLARE
	result doc_node_kind_refs;
	kilroy_was_here boolean := false;
	_this regprocedure := 'create_dynamic_kind(text)';
BEGIN
	LOOP
		SELECT ref INTO result FROM dynamic_doc_node_kind_rows
		WHERE name_ = $1;
		IF FOUND THEN RETURN result; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO dynamic_doc_node_kind_rows(name_) VALUES($1);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
		END;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_dynamic_kind_method(
	doc_node_kind_refs, _op regprocedure, _method regprocedure
) RETURNS regprocedure AS $$
DECLARE
	result regprocedure;
	kilroy_was_here boolean := false;
	_this regprocedure := 'create_dynamic_kind_method(
		doc_node_kind_refs, regprocedure, regprocedure
	)';
BEGIN
	LOOP
		result := try_dynamic_kind_method($1, $2);
		IF result IS NOT NULL THEN
			IF result = $3 THEN RETURN result; END IF;
			RAISE EXCEPTION '% % %: % != %', this, $1, $2, $3, result;
		END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO dynamic_kind_methods(kind_, operation_, method_)
			VALUES($1, $2, $3);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % % raised %!',
				this, $1, $2, $3, 'unique_violation';
		END;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_dynamic_kind_text_method(
	text, _body text, _refs regtype = 'doc_node_kind_refs', _ text = NULL
) RETURNS SETOF regprocedure AS $$
	SELECT create_dynamic_kind_method(
		find_dynamic_doc_node_kind($1), 'ref_env_crefs_chiln_text_op(
			refs, env_refs, crefs, doc_node_refs[]
		)', 	_method
	) FROM declare_proc(create_func(
		$1 || '_text', $2,
		_returns := 'text',
		_args := ARRAY[
			meta_arg($3, '_nil'),
			meta_arg('env_refs', '_env', 'env_nil()'),
			meta_arg('crefs', '_crefs', 'crefs_nil()'),
			meta_arg('doc_node_refs[]', '_chiln', '''{}''')
		],
		_ := COALESCE(
			$4,
			'nil ref, doc env, etc. --> special dynamic text value'
		),
		_by := 'create_dynamic_kind_text_method(text,text,regtype,text)'
	)) _method
$$ LANGUAGE SQL;

/*
CREATE OR REPLACE FUNCTION create_special_kind_text_method(
	text, _body text, _class regclass,
	_refs regtype = 'doc_node_kind_refs', _ text = NULL
) RETURNS SETOF typed_object_methods AS $$
	SELECT type_class_op_method(
		$4, $3,
		'ref_env_crefs_chiln_text_op(refs,env_refs,crefs,doc_node_refs[])',
		create_special_kind_text_function($1, $2, $4, $5)
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION declare_special_kind_text(
	text, _body text,
	_class regclass = NULL, _refs regtype = 'doc_node_kind_refs',
	_ text = NULL, 	_exact_ boolean = false
) RETURNS SETOF typed_object_methods AS $$
	SELECT create_special_kind_text_method($1,$2,class_,$4,$5)
	FROM COALESCE(
		$3, (declare_special_kind_class($1,$6,$4)).class_
	) class_
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION special_kind(regclass)
RETURNS doc_node_kind_refs AS $$
	SELECT unchecked_doc_node_kind_from_class_id($1, 0)
$$ LANGUAGE SQL;
*/
