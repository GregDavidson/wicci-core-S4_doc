-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('doc-types.sql', '$Id');

--	Wicci Project
--	doc_langs -- document languages

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * doc_lang_name

-- Documents consist of nodes whose data objects are
-- instances of kinds.  The permitted kinds and data objects
-- are constrained by the document's language.

SELECT create_name_ref_schema(
	'doc_lang_name', name_type := 'citext'
);

SELECT declare_doc_lang_name(
  'show1', 'text',
	'xml', 'html', 'xhtml', 'xhtml-strict', 'html4', 'html4-strict',
	'css', 'javascript', 'svg',
	'png', 'gif', 'jpeg','binary',
	'ajax'
);

-- ** doc_kind_types

SELECT create_env_name_type_func(
	'env_doc_lang', 'doc_lang_name_refs'
);

CREATE TABLE IF NOT EXISTS doc_kind_types (
	kind regclass NOT NULL,
	lang doc_lang_name_refs
		NOT NULL REFERENCES doc_lang_name_rows,
	UNIQUE(kind, lang),
	env env_refs REFERENCES env_rows -- NOT NULL
	-- CHECK(env_doc_lang(env) = lang)
);
COMMENT ON TABLE doc_kind_types IS
'Relates document kind classes to the document
languages they are used for and (through the
associated envirornment) any other constraints
which should be respected.';

COMMENT ON COLUMN doc_kind_types.env IS
'Used to constrain possible kinds which can be
in parent/child relationships when nodes are
constructed using those kinds.  Not in use
yet - when code is upgraded, make this field
be NOT NULL!!';

CREATE OR REPLACE FUNCTION try_declare_doc_kind_lang_type(
	regclass, doc_lang_name_refs, env_refs = env_nil()
) RETURNS regclass AS $$
	DECLARE
		tuple RECORD;
		kilroy_was_here boolean := false;
		this regprocedure := 'try_declare_doc_kind_lang_type(
			regclass, doc_lang_name_refs, env_refs)';
	BEGIN
		LOOP
			SELECT * INTO tuple FROM doc_kind_types
			WHERE kind = $1 AND lang = $2;
			IF FOUND THEN
				IF NOT is_nil($3) and NOT is_nil(tuple.env) THEN
					IF tuple.env != $3 THEN
						RAISE EXCEPTION '% % % env % != %', this, $1, $2, env, $3;
					END IF;
				END IF;
				RETURN tuple.kind;
			END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% % % looping', this, $1, $2, $3;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO doc_kind_types(kind, lang, env) VALUES
				($1, $2, CASE WHEN is_nil($3) THEN NULL ELSE $3 END);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % % raised %!',
						this, $1, $2, $3, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION declare_doc_kind_lang_type(
	regclass, doc_lang_name_refs, env_refs = env_nil()
) RETURNS regclass AS $$
	SELECT non_null(
		try_declare_doc_kind_lang_type($1, $2, $3),
		'declare_doc_kind_lang_type(
			regclass, doc_lang_name_refs, env_refs)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION declare_doc_kind_type(regclass, env_refs)
RETURNS regclass AS $$
	SELECT non_null(
		try_declare_doc_kind_lang_type( $1, try_env_doc_lang($2), $2 ),
		'declare_doc_kind_type(regclass, env_refs)'
	)
$$ LANGUAGE SQL;

-- ** doc_lang_families

CREATE TABLE IF NOT EXISTS doc_lang_families (
	subset doc_lang_name_refs
		UNIQUE NOT NULL REFERENCES doc_lang_name_rows,
	superset doc_lang_name_refs
		NOT NULL REFERENCES doc_lang_name_rows
);
COMMENT ON TABLE doc_lang_families IS
'Allows for document languages to be registered
as describing subsets of more general languages.
The more general languages can be considered
both as languages and also as language families.

All languages are either "ajax", some form of "text"
or will be considered as literal bytes to be pulled
forth from a large object in binary.
';

-- *** Service functions

CREATE OR REPLACE
FUNCTION try_doc_lang_family(doc_lang_name_refs) 
RETURNS doc_lang_name_refs AS $$
	SELECT superset FROM doc_lang_families WHERE subset = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION doc_lang_family(doc_lang_name_refs)
RETURNS doc_lang_name_refs AS $$
	SELECT non_null(
		try_doc_lang_family($1),
		'doc_lang_family(doc_lang_name_refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_doc_family_lang(doc_lang_name_refs) 
RETURNS doc_lang_name_refs AS $$
	SELECT subset FROM doc_lang_families WHERE superset = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION doc_family_lang(doc_lang_name_refs)
RETURNS doc_lang_name_refs AS $$
	SELECT non_null(
		try_doc_family_lang($1),
		'doc_family_lang(doc_lang_name_refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION try_declare_doc_lang_family(
	doc_lang_name_refs, doc_lang_name_refs
) RETURNS doc_lang_name_refs AS $$
	DECLARE
		tuple RECORD;
		kilroy_was_here boolean := false;
		this regprocedure :=
			'try_declare_doc_lang_family(
				doc_lang_name_refs,doc_lang_name_refs
			)';
	BEGIN
		LOOP
			SELECT * INTO tuple FROM doc_lang_families WHERE subset = $1;
			IF FOUND THEN
				IF $2 <> tuple.superset THEN
					RAISE EXCEPTION '%(%,%!=%)', this, $1, $2, tuple.superset;
				END IF;
				RETURN tuple.superset;
			END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with %', this, $1;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO doc_lang_families(subset, superset)
				VALUES($1, $2);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION declare_doc_lang_family(
	doc_lang_name_refs, doc_lang_name_refs
) RETURNS doc_lang_name_refs AS $$
	SELECT non_null(
		try_declare_doc_lang_family($1, $2),
		'declare_doc_lang_family(
			doc_lang_name_refs, doc_lang_name_refs
		)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION in_doc_lang_family(
	doc_lang_name_refs,doc_lang_name_refs
) RETURNS boolean AS $$
	WITH RECURSIVE fam(f) AS (
			SELECT $1
		UNION ALL
			SELECT superset FROM fam, doc_lang_families
			WHERE subset = f
	) SELECT $2 IN (SELECT f FROM fam)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION ok_doc_lang_kind_class(doc_lang_name_refs, regclass) 
RETURNS boolean AS $$
	SELECT lang = $1 OR lang = doc_lang_name_nil()
		OR in_doc_lang_family(lang, $1)
	FROM doc_kind_types WHERE kind = $2
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION ok_doc_lang_kind(doc_lang_name_refs, refs) 
RETURNS boolean AS $$
	SELECT ok_doc_lang_kind_class($1, ref_table($2))
$$ LANGUAGE sql;
