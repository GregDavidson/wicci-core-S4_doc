-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('uri-code.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	ref-types for representing xml uris

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * uri_domain_name

SELECT declare_uri_domain_name('localhost', 'wicci.org');
SELECT find_uri_domain_name('localhost'); -- test!!

-- * uri_entity_type_name

SELECT declare_uri_entity_type_name('mailto', 'user', 'group');

-- * uri_entity_pair

CREATE OR REPLACE
FUNCTION uri_entity_pair_pattern() RETURNS text AS $$
	SELECT '^(?:([^:]+):)?(.*)$'::text
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_uri_entity_pair_match(text) RETURNS text[] AS $$
	SELECT ARRAY[ COALESCE(part[1], ''), part[2] ]
	FROM try_str_match($1, uri_entity_pair_pattern()) part
	WHERE part[2] IS NOT NULL
$$ LANGUAGE SQL IMMUTABLE;

-- ** type uri_entity_pair_refs methods

CREATE OR REPLACE
FUNCTION try_uri_entity_type_name(uri_entity_pair_refs) 
RETURNS uri_entity_type_name_refs AS $$
	SELECT type_ FROM uri_entity_pair_rows WHERE ref = $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION uri_entity_type_name(uri_entity_pair_refs)
RETURNS uri_entity_type_name_refs AS $$
	SELECT non_null(
		try_uri_entity_type_name($1), 'uri_entity_type_name(uri_entity_pair_refs)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION uri_entity_pair_text(uri_entity_pair_refs)
RETURNS text AS $$
	SELECT CASE
		WHEN is_nil($1) THEN ''
		ELSE (
			SELECT CASE type_
				WHEN uri_entity_type_name_nil() THEN ''
				WHEN uri_entity_type_name_other() THEN ''
				ELSE uri_entity_type_name_text(type_) || ':'
			END ||  name_
		FROM uri_entity_pair_rows WHERE ref = $1
		)
	END
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION uri_entity_pair_length(uri_entity_pair_refs)
RETURNS integer AS $$
	SELECT CASE
		WHEN is_nil($1) THEN 0
		ELSE (
			SELECT CASE type_
				WHEN uri_entity_type_name_nil() THEN 0
				WHEN uri_entity_type_name_other() THEN 0
				ELSE uri_entity_type_name_length(type_) + 1
			END + octet_length(name_)
		FROM uri_entity_pair_rows WHERE ref = $1
		)
	END
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_uri_entity_pair(uri_entity_type_name_refs, text)
RETURNS uri_entity_pair_refs AS $$
  SELECT ref FROM uri_entity_pair_rows
	WHERE type_ = $1 AND name_ = lower($2)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_uri_entity_pair(uri_entity_type_name_refs, text)
RETURNS uri_entity_pair_refs AS $$
  SELECT non_null(
		try_uri_entity_pair($1, $2),
		'find_uri_entity_pair(uri_entity_type_name_refs, text)',
		$2
	)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_every_uri_entity_pair(text, text)
RETURNS uri_entity_pair_refs AS $$
	SELECT try_uri_entity_pair(try_uri_entity_type_name($1::citext), $2)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_other_uri_entity_pair(text, text)
RETURNS uri_entity_pair_refs AS $$
		SELECT try_uri_entity_pair(uri_entity_type_name_other(), $1 || ':' || $2)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_uri_entity_pair(text, text)
RETURNS uri_entity_pair_refs AS $$
  SELECT COALESCE(
		try_every_uri_entity_pair($1, $2),
		try_other_uri_entity_pair($1, $2)
	)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_uri_entity_pair(text) 
RETURNS uri_entity_pair_refs AS $$
  SELECT try_uri_entity_pair(pair[1], pair[2])
	FROM try_uri_entity_pair_match($1) pair
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_uri_entity_pair(text)
RETURNS uri_entity_pair_refs AS $$
	SELECT non_null(
		try_uri_entity_pair($1), 'find_uri_entity_pair(text)', $1
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_get_uri_entity_pair(uri_entity_type_name_refs, text) 
RETURNS uri_entity_pair_refs AS $$
DECLARE
	maybe uri_entity_pair_refs;
	_name TEXT = lower($2);
	kilroy_was_here boolean := false;
	this regprocedure :=
		'try_get_uri_entity_pair(uri_entity_type_name_refs, text)';
BEGIN
	IF $1 = uri_entity_type_name_nil() AND _name = '' THEN
		RETURN uri_entity_pair_nil();
	END IF;
	LOOP
		maybe := try_uri_entity_pair($1, _name);
		IF maybe IS NOT NULL THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO uri_entity_pair_rows(type_, name_)
			VALUES ($1, _name);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_uri_entity_pair(uri_entity_type_name_refs, text)
RETURNS uri_entity_pair_refs AS $$
	SELECT non_null(
		try_get_uri_entity_pair($1,$2),
		'get_uri_entity_pair(uri_entity_type_name_refs,text)',
		$2
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_get_uri_entity_pair(text, text) 
RETURNS uri_entity_pair_refs AS $$
  SELECT COALESCE(
		try_get_uri_entity_pair(try_uri_entity_type_name($1::citext), $2),
		try_get_uri_entity_pair(uri_entity_type_name_other(), $1 || ':' || $2)
	)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_uri_entity_pair_(text, text)
RETURNS uri_entity_pair_refs AS $$
	SELECT non_null(
		try_get_uri_entity_pair($1,$2), 'get_uri_entity_pair_(text,text)',
		$1, $2
	)
$$ LANGUAGE SQL;

-- what happens if the value is empty???
-- str_match will doubtless return a NULL!!!
CREATE OR REPLACE
FUNCTION try_get_uri_entity_pair(text)
RETURNS uri_entity_pair_refs AS $$
  SELECT try_get_uri_entity_pair(name_value[1], name_value[2])
	FROM try_uri_entity_pair_match($1) name_value
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_uri_entity_pair(text)
RETURNS uri_entity_pair_refs AS $$
	SELECT non_null(
		try_get_uri_entity_pair($1), 'get_uri_entity_pair(text)',
		$1
  )
$$ LANGUAGE SQL STRICT;

-- ** uri_entity_pair_refs classes declarations

-- SELECT type_class_io(
-- 	'uri_entity_pair_refs', 'uri_entity_pair_rows',
-- 	'uri_entity_pair_refs(text)', 'uri_entity_pair_text(uri_entity_pair_refs)'
-- );

SELECT type_class_in(
	'uri_entity_pair_refs', 'uri_entity_pair_rows',
	'try_uri_entity_pair(text)'
);

SELECT type_class_out(
	'uri_entity_pair_refs', 'uri_entity_pair_rows',
	'uri_entity_pair_text(uri_entity_pair_refs)'
);

SELECT type_class_op_method(
	'uri_entity_pair_refs', 'uri_entity_pair_rows',
	'ref_text_op(refs)', 'uri_entity_pair_text(uri_entity_pair_refs)'
);

SELECT type_class_op_method(
	'uri_entity_pair_refs', 'uri_entity_pair_rows',
	'ref_length_op(refs)', 'uri_entity_pair_length(uri_entity_pair_refs)'
);

-- * uri_query

-- ** type uri_query_refs methods

CREATE OR REPLACE
FUNCTION try_uri_query_text(uri_query_refs)  
RETURNS text AS $$
	SELECT CASE
		WHEN is_nil($1) THEN ''
		ELSE (
			SELECT array_to_string(
				ARRAY(
					SELECT COALESCE(keys[i], '') || COALESCE('=' || vals[i], '')
					FROM array_indices(keys) i
				), '&'
			) FROM uri_query_rows WHERE ref = $1
		)
	END
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION uri_query_text(uri_query_refs) 
RETURNS text AS $$
	SELECT non_null(
		try_uri_query_text($1), 'uri_query_text(uri_query_refs)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_uri_query_length(uri_query_refs) 
RETURNS integer AS $$
	SELECT octet_length(try_uri_query_text($1))
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION uri_query_length(uri_query_refs)
RETURNS integer AS $$
	SELECT non_null(
		try_uri_query_length($1), 'uri_query_length(uri_query_refs)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION uri_query_pair_pattern() RETURNS text AS $$
	SELECT '^([^=]*)(?:=(.*[^[:space:]]))?$'::text
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_uri_query_pair_match(text) RETURNS text[] AS $$
	SELECT try_str_match($1, uri_query_pair_pattern())
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_uri_query_pair_key(text) RETURNS text AS $$
	SELECT (try_uri_query_pair_match($1))[1]
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_uri_query_pair_val(text) RETURNS text AS $$
	SELECT (try_uri_query_pair_match($1))[2]
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE FUNCTION try_uri_query_parse(
	text, OUT _keys_ text[], OUT _vals_ text[]
)  AS $$
	SELECT ARRAY(
		SELECT try_uri_query_pair_key(a[i]) FROM generate_series(
			array_lower(a, 1), array_upper(a, 1)
		) i
	), ARRAY(
		SELECT try_uri_query_pair_val(a[i]) FROM generate_series(
			array_lower(a, 1), array_upper(a, 1)
		) i
	) FROM string_to_array($1, '&') a
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_uri_query(text) 
RETURNS uri_query_refs AS $$
  SELECT ref
	FROM uri_query_rows, try_uri_query_parse($1) AS a(_keys_, _vals_)
	WHERE keys = _keys_ AND vals = _vals_
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_uri_query(text)
RETURNS uri_query_refs AS $$
	SELECT non_null( try_uri_query($1), 'find_uri_query(text)', $1 )
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_get_uri_query(text[], text[]) 
RETURNS uri_query_refs AS $$
DECLARE
	maybe uri_query_refs;
	kilroy_was_here boolean := false;
	this regprocedure := 'get_uri_query(text[], text[])';
BEGIN
	IF array_lower($1, 1) IS NULL AND array_lower($2, 1) IS NULL THEN
		RETURN uri_query_nil();
	END IF;
	LOOP
		SELECT INTO maybe ref FROM uri_query_rows
		WHERE keys = $1 AND vals = $2;
		IF FOUND THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO uri_query_rows(keys, vals) VALUES ($1, $2);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION get_uri_query(text[], text[])
RETURNS uri_query_refs AS $$
	SELECT non_null(
		try_get_uri_query($1,$2), 'get_uri_query(text[],text[])'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_get_uri_query(text)  RETURNS uri_query_refs AS $$
	SELECT try_get_uri_query(_keys_, _vals_)
	FROM try_uri_query_parse($1) a(_keys_, _vals_)
	WHERE _keys_ IS NOT NULL AND _vals_ IS NOT NULL
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_uri_query(text) RETURNS uri_query_refs AS $$
	SELECT non_null(try_get_uri_query($1), 'get_uri_query(text)', $1)
$$ LANGUAGE SQL;

-- ** uri_query_refs classes declarations

-- SELECT type_class_io(
-- 	'uri_query_refs', 'uri_query_rows',
-- 	'uri_query_refs(text)', 'uri_query_text(uri_query_refs)'
-- );

SELECT type_class_in(
	'uri_query_refs', 'uri_query_rows',
	'try_uri_query(text)'
);

SELECT type_class_out(
	'uri_query_refs', 'uri_query_rows',
	'uri_query_text(uri_query_refs)'
);

SELECT type_class_op_method(
	'uri_query_refs', 'uri_query_rows',
	'ref_text_op(refs)', 'uri_query_text(uri_query_refs)'
);

SELECT type_class_op_method(
	'uri_query_refs', 'uri_query_rows',
	'ref_length_op(refs)', 'uri_query_length(uri_query_refs)'
);

-- ** uri_query_key

CREATE OR REPLACE
FUNCTION uri_query_values(uri_query_refs, text) 
RETURNS SETOF text AS $$
	SELECT array_key_vals(keys, $2, vals)
	FROM uri_query_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_uri_query_value(uri_query_refs, text) 
RETURNS text AS $$
	SELECT uri_query_values($1, $2) LIMIT 1
$$ LANGUAGE SQL;

DROP OPERATOR IF EXISTS ^ (uri_query_refs, text) CASCADE;

CREATE OPERATOR ^ (
		leftarg = uri_query_refs,
		rightarg = text,
		procedure = try_uri_query_value
);

-- * uri_domain_hack

CREATE OR REPLACE FUNCTION uri_domain_hack(
	uri_domain_name_refs, uri_query_refs = uri_query_nil()
) RETURNS uri_domain_name_refs AS $$
	SELECT CASE
		WHEN $1 != 'localhost'::uri_domain_name_refs THEN $1
		ELSE COALESCE(
			try_uri_domain_name(($2 ^ 'host')::citext),
			'wicci.org'::uri_domain_name_refs
		)
	END
$$ LANGUAGE SQL STABLE;

-- * page_uri

CREATE OR REPLACE
FUNCTION uri_pattern() RETURNS text AS $$
	SELECT '^'                            -- begin anchor
			|| '(?:([a-z]+)://)?'               -- protocol = part1
			|| '(?:(?:([a-z]*):)?([^@?]+)@)?'		-- type:entity = parts 2&3
			|| '([^.:/#?]+(?:[.][^.:/#?]+)*)?' -- domain = part 4
			|| '(?:[:]([0-9]+))?'               -- port number = part5
			|| '(?:/(/?[^/#?]+(?:/[^/#?]+)*))?' -- directory path = part 6
			|| '/?'                           -- trailing slash
			|| '(?:#([^?]*))?'                  -- tag = part7
			|| E'(?:\\?([^,=]+=[^,]*(?:,[^,=]+=[^,]*)*)?)?' -- settings = part8
			|| '$'                            -- end anchor
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION uri_pattern() IS
'I''m using an extra slash beginning the path to indicate a
page-uri which is relative to document root.  Such an extra
slash should only be permitted for page-uris';

CREATE OR REPLACE
FUNCTION try_page_uri_match(text) RETURNS text[] AS $$
	SELECT ARRAY[
		COALESCE(part[2], ''), COALESCE(part[3], ''),
		COALESCE(part[4], ''), COALESCE('/' || part[6], '')
	] FROM try_str_match($1, uri_pattern()) part
$$ LANGUAGE SQL IMMUTABLE;

-- CREATE OR REPLACE
-- FUNCTION page_uri_pattern() RETURNS text AS $$
-- 	SELECT '^'                            -- begin anchor
-- 			|| '(?:[a-z]+)://?'               -- protocol?
-- 			|| '(?:(?:([a-z]*):)?([^@?]+)@)?'		-- type:entity = parts 1&2
-- 			|| '([^:/#?]*)'											-- domain = part 3
-- 			|| '(?:[:][0-9]+)?'									-- port?
-- 			|| '/*([^#?]*)/*'									-- directory path = part 4
-- 			|| '(?:[#?].*)?'                  -- tag? query?
-- 			|| '$'                            -- end anchor
-- $$ LANGUAGE SQL IMMUTABLE;

-- CREATE OR REPLACE
-- FUNCTION try_page_uri_match(text) RETURNS text[] AS $$
-- 	SELECT ARRAY[
-- 		COALESCE(part[1], ''), COALESCE(part[2], ''),
-- 		COALESCE(part[3], ''), COALESCE(part[4], '')
-- 	] FROM try_str_match($1, page_uri_pattern()) part
-- $$ LANGUAGE SQL IMMUTABLE;

-- ** type page_uri_refs methods

CREATE OR REPLACE
FUNCTION try_uri_entity_type_name(page_uri_refs) 
RETURNS uri_entity_type_name_refs AS $$
	SELECT uri_entity_type_name(entity_) FROM page_uri_rows
	WHERE ref = $1 AND non_nil(entity_)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION uri_entity_type_name(page_uri_refs)
RETURNS uri_entity_type_name_refs AS $$
	SELECT non_null(
		try_uri_entity_type_name($1), 'uri_entity_type_name(page_uri_refs)'
	)
$$ LANGUAGE SQL;

-- adjusting whether the path begins with a leading
-- / or not is problematic.  Either all url-related paths
-- should start with a / or none should or there should
-- be a well-motivated reason why some do and some
-- don't from which it would be clear what to add when
-- they don't.
CREATE OR REPLACE
FUNCTION page_uri_text(page_uri_refs, int) RETURNS text AS $$
	SELECT
		CASE WHEN is_nil(entity_) THEN ''
		ELSE  uri_entity_pair_text(entity_) || '@'
		END
		|| uri_domain_name_text(domain_)
		|| CASE WHEN $2 = 0 THEN '' ELSE ':' || $2::text END
		|| CASE WHEN is_nil(path_) THEN '' ELSE '/' END
		|| uri_path_name_text(path_)
	FROM page_uri_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION page_uri_text(page_uri_refs) RETURNS text AS $$
	SELECT page_uri_text($1, 0)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION try_page_uri(
	uri_entity_pair_refs, uri_domain_name_refs,
	uri_path_name_refs
) RETURNS page_uri_refs AS $$
  SELECT ref FROM page_uri_rows
	WHERE entity_ = $1 AND domain_ = uri_domain_hack($2)
	AND path_ = $3
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_page_uri(text)
RETURNS page_uri_refs AS $$
  SELECT try_page_uri(
		try_uri_entity_pair(part[1], part[2]),
		try_uri_domain_name(part[3]::citext),
		try_uri_path_name(part[4])
	) FROM try_page_uri_match($1) part
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_page_uri(text)
RETURNS page_uri_refs AS $$
  SELECT non_null( try_page_uri($1), 'find_page_uri(text)', $1 )
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION try_get_page_uri(
	uri_entity_pair_refs, uri_domain_name_refs, uri_path_name_refs
) RETURNS page_uri_refs AS $$
DECLARE
	kilroy_was_here boolean := false;
	_domain uri_domain_name_refs := uri_domain_hack($2);
	maybe page_uri_refs := try_page_uri($1, _domain, $3);
	this regprocedure :=
'try_get_page_uri(uri_entity_pair_refs,uri_domain_name_refs,uri_path_name_refs)';
BEGIN
	LOOP
		IF maybe IS NOT NULL THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO page_uri_rows(entity_, domain_, path_)
			VALUES ($1, _domain, $3) RETURNING ref INTO maybe;
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

-- the idea with this exception rigamarole is to
-- undo the creation of any of the components
-- if they can't all be created.
CREATE OR REPLACE
FUNCTION try_get_page_uri(text) RETURNS page_uri_refs AS $$
DECLARE
	part text[] := try_page_uri_match($1);
	maybe page_uri_refs;
BEGIN
	IF part IS NULL THEN RETURN NULL; END IF;
	BEGIN
		SELECT into maybe try_get_page_uri(
			try_get_uri_entity_pair(part[1], part[2]),
			try_get_uri_domain_name(part[3]::citext),
			try_get_uri_path_name(part[4])
		);
		IF maybe IS NULL THEN
			RAISE no_data_found;
		END IF;
	EXCEPTION
		WHEN no_data_found THEN RETURN NULL;
	END;
	RETURN maybe;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_page_uri(text) RETURNS page_uri_refs AS $$
	SELECT non_null(
		try_get_page_uri($1), 'get_page_uri(text)', $1
	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION get_page_uri(text)
IS 'Called by doc-to-sql code.';

-- ** page_uri_refs classes declarations

SELECT type_class_in(
	'page_uri_refs', 'page_uri_rows', 'try_page_uri(text)'
);

SELECT type_class_out(
	'page_uri_refs', 'page_uri_rows', 'page_uri_text(page_uri_refs)'
);

SELECT type_class_op_method(
	'page_uri_refs', 'page_uri_rows',
	'ref_text_op(refs)', 'page_uri_text(page_uri_refs)'
);

-- * entity_uri

-- CREATE OR REPLACE
-- FUNCTION entity_uri_pattern() RETURNS text AS $$
-- 	SELECT '^'                            -- begin anchor
-- 			|| '([a-z]*:)?([^@?]+)@'		-- type:entity = parts 1&2
-- 			|| '([^:/#?]*)'											-- domain = part 3
-- 			|| '/*([^:#?]*)/*'									-- directory path = part 4
-- 			|| '$'                            -- end anchor
-- $$ LANGUAGE SQL IMMUTABLE;

-- CREATE OR REPLACE
-- FUNCTION try_entity_uri_match(text) RETURNS text[] AS $$
-- 	SELECT try_str_match($1, entity_uri_pattern())
-- $$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_entity_uri_match(text) RETURNS text[] AS $$
	SELECT _parts FROM try_page_uri_match($1) _parts
	WHERE _parts[2] != ''
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_uri_entity_type_name(entity_uri_refs) 
RETURNS uri_entity_type_name_refs AS $$
	SELECT try_uri_entity_type_name(page)
	FROM entity_uri_rows WHERE ref = $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION uri_entity_type_name(entity_uri_refs)
RETURNS uri_entity_type_name_refs AS $$
	SELECT non_null(
		try_uri_entity_type_name($1), 'uri_entity_type_name(entity_uri_refs)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION is_entity_uri_type(entity_uri_refs, uri_entity_type_name_refs)
RETURNS bool AS $$
	SELECT uri_entity_type_name($1) = $2
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION entity_uri_text(entity_uri_refs)
RETURNS text AS $$
	SELECT page_uri_text(page)
	FROM entity_uri_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_entity_uri(page_uri_refs) 
RETURNS entity_uri_refs AS $$
  SELECT ref FROM entity_uri_rows WHERE page = $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION entity_uri(page_uri_refs)
RETURNS entity_uri_refs AS $$
	SELECT non_null( try_entity_uri($1), 'entity_uri(page_uri_refs)' 	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_entity_uri_page(entity_uri_refs) 
RETURNS page_uri_refs AS $$
  SELECT page FROM entity_uri_rows WHERE ref = $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION entity_uri_page(entity_uri_refs)
RETURNS page_uri_refs AS $$
	SELECT non_null(
		try_entity_uri_page($1), 'entity_uri_page(entity_uri_refs)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_entity_uri(text) 
RETURNS entity_uri_refs AS $$
  SELECT try_entity_uri(try_page_uri($1))
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_entity_uri(text)
RETURNS entity_uri_refs AS $$
	SELECT non_null( try_entity_uri($1), 'find_entity_uri(text)', $1 )
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_entity_uri(text, uri_entity_type_name_refs)  
RETURNS entity_uri_refs AS $$
  SELECT _entity FROM try_entity_uri($1) _entity
	WHERE try_uri_entity_type_name(_entity) = $2
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_entity_uri(text, uri_entity_type_name_refs) 
RETURNS entity_uri_refs AS $$
	SELECT non_null(
		try_entity_uri($1,$2), 'find_entity_uri(text,uri_entity_type_name_refs)', $1
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_get_entity_uri(page_uri_refs)
RETURNS entity_uri_refs AS $$
DECLARE
	_entity_pair uri_entity_pair_refs;
	_entity entity_uri_refs;
	kilroy_was_here boolean := false;
	this regprocedure := 'try_get_entity_uri(page_uri_refs)';
BEGIN
		SELECT INTO _entity_pair entity_
		FROM page_uri_rows WHERE ref = $1;
		IF NOT FOUND THEN RETURN NULL; END IF; -- or thow an error?
		IF is_nil(_entity_pair) THEN RETURN NULL; END IF;
	LOOP
		SELECT INTO _entity ref FROM entity_uri_rows WHERE page = $1;
		IF FOUND THEN RETURN _entity; END IF;		
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO entity_uri_rows(ref, page)
			VALUES (unchecked_entity_uri_from_id(ref_id($1)), $1);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

-- the idea with this exception rigamarole is to
-- undo the creation of any of the components
-- if they can't all be created.
CREATE OR REPLACE
FUNCTION try_get_entity_uri(text) RETURNS entity_uri_refs AS $$
DECLARE
	part text[] := try_entity_uri_match($1);
	maybe entity_uri_refs;
BEGIN
	IF $1 = '' THEN RETURN entity_uri_nil(); END IF;
	IF part IS NULL THEN RETURN NULL; END IF;
	BEGIN
		SELECT INTO maybe try_get_entity_uri(try_get_page_uri($1));
		IF maybe IS NULL THEN
			RAISE no_data_found;
		END IF;
	EXCEPTION
		WHEN no_data_found THEN RETURN NULL;
	END;
	RETURN maybe;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_entity_uri(text) RETURNS entity_uri_refs AS $$
	SELECT non_null(
		try_get_entity_uri($1), 'get_entity_uri(text)', $1
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_get_entity_uri(page_uri_refs, uri_entity_type_name_refs)
RETURNS entity_uri_refs AS $$
DECLARE
	_entity_pair uri_entity_pair_refs;
	_entity entity_uri_refs;
	kilroy_was_here boolean := false;
	this regprocedure
		:= 'try_get_entity_uri(page_uri_refs,uri_entity_type_name_refs)';
BEGIN
	IF try_uri_entity_type_name($1) IS DISTINCT FROM $2 THEN
		RAISE no_data_found;
	END IF;
	LOOP
		SELECT INTO _entity ref FROM entity_uri_rows WHERE page = $1;
		IF FOUND THEN RETURN _entity; END IF;		
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO entity_uri_rows(ref, page)
			VALUES (unchecked_entity_uri_from_id(ref_id($1)), $1);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

-- the idea with this exception rigamarole is to
-- undo the creation of any of the components
-- if they can't all be created.
CREATE OR REPLACE
FUNCTION try_get_entity_uri(text, uri_entity_type_name_refs)
RETURNS entity_uri_refs AS $$
DECLARE
	part text[] := try_entity_uri_match($1);
	maybe entity_uri_refs;
BEGIN
	IF part IS NULL THEN RETURN NULL; END IF;
	BEGIN
		SELECT INTO maybe try_get_entity_uri(try_get_page_uri($1), $2);
		IF maybe IS NULL THEN
			RAISE no_data_found;
		END IF;
	EXCEPTION
		WHEN no_data_found THEN RETURN NULL;
	END;
	RETURN maybe;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_entity_uri(text, uri_entity_type_name_refs)
RETURNS entity_uri_refs AS $$
	SELECT non_null(
		try_get_entity_uri($1,$2), 'get_entity_uri(text,uri_entity_type_name_refs)'
	)
$$ LANGUAGE sql;

SELECT type_class_in(
	'entity_uri_refs', 'entity_uri_rows', 'try_entity_uri(text)'
);

SELECT type_class_out(
	'entity_uri_refs', 'entity_uri_rows', 'entity_uri_text(entity_uri_refs)'
);

SELECT type_class_op_method(
	'entity_uri_refs', 'entity_uri_rows',
	'ref_text_op(refs)', 'entity_uri_text(entity_uri_refs)'
);

-- * uri

CREATE OR REPLACE
FUNCTION try_page_uri(uri_refs)  RETURNS page_uri_refs AS $$
	SELECT page FROM uri_rows WHERE ref::refs = $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_page_uri(uri_refs) RETURNS page_uri_refs AS $$
	SELECT non_null( try_page_uri($1), 'find_page_uri(uri_refs)' )
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_entity_uri(uri_refs)  RETURNS entity_uri_refs AS $$
	SELECT try_get_entity_uri(try_page_uri($1))
$$ LANGUAGE SQL STRICT;

-- CREATE OR REPLACE
-- FUNCTION uri_pattern() RETURNS text AS $$
-- 	SELECT '^'                            -- begin anchor
-- 			|| '(?:([a-z]+)://)?'               -- protocol = part1
-- 			|| '(?:(?:([a-z]*):)?([^@?]+)@)?'		-- type:entity = parts 2&3
-- 			|| '([^.:/#?]+(?:[.][^.:/#?]+)*)?' -- domain = part 4
-- 			|| '(?:[:]([0-9]+))?'               -- port number = part5
-- 			|| '(?:/([^/#?]+(?:/[^/#?]+)*))?' -- directory path = part 6
-- 			|| '/?'                           -- trailing slash
-- 			|| '(?:#([^?]*))?'                  -- tag = part7
-- 			|| E'(?:\\?([^,=]+=[^,]*(?:,[^,=]+=[^,]*)*)?)?' -- settings = part8
-- 			|| '$'                            -- end anchor
-- $$ LANGUAGE SQL IMMUTABLE;

-- figure out what this gives for different examples;
-- do we need to normalize it to exactly 4 elements?
-- do we want to use NULL or empty strings for missing
-- components?
CREATE OR REPLACE
FUNCTION try_uri_match(text) RETURNS text[] AS $$
	SELECT ARRAY[
		COALESCE(part[1], ''), COALESCE(part[2], ''),
		COALESCE(part[3], ''), COALESCE(part[4], ''),
		COALESCE(part[5], ''), COALESCE(part[6], ''),
		COALESCE(part[7], ''), COALESCE(part[8], '')
	] FROM try_str_match($1, uri_pattern()) part
	WHERE part IS NOT NULL
$$ LANGUAGE SQL IMMUTABLE;

-- ** type uri_refs methods

CREATE OR REPLACE
FUNCTION uri_text(uri_refs)
RETURNS text AS $$
	SELECT
		CASE WHEN protocol = '' THEN ''
		ELSE protocol || '://' END
		|| 	page_uri_text(page, uri_port_to_value(port))
		|| CASE WHEN tag = '' THEN '' ELSE '#' || tag END
		|| CASE WHEN is_nil(query) THEN ''
				ELSE '?' || uri_query_text(query)
		END FROM uri_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION try_uri(
	text, page_uri_refs, int, text, uri_query_refs
) RETURNS uri_refs AS $$
  SELECT ref FROM uri_rows
	WHERE protocol = $1 AND page = $2
	AND uri_port_to_value(port) = $3
	AND tag = $4 AND query = $5
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_uri(text) RETURNS uri_refs AS $$
  SELECT try_uri(
		part[1],										-- protocol?
		try_page_uri(
			try_uri_entity_pair(part[2], part[3]),
			try_uri_domain_name(part[4]::citext),
			try_uri_path_name(part[6])
		),
		CASE WHEN part[5] = '' THEN 0 ELSE part[5]::int END, -- port?
		part[7],										-- tag?
		try_uri_query(part[8])
	) FROM try_uri_match($1) part
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_uri(text) RETURNS uri_refs AS $$
  SELECT non_null( try_uri($1), 'find_uri(text)', $1 )
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION try_get_uri(
	text, page_uri_refs, int, text, uri_query_refs
) RETURNS uri_refs AS $$
DECLARE
	maybe uri_refs;
	kilroy_was_here boolean := false;
	this regprocedure :=
'try_get_uri(text,page_uri_refs,int,text,uri_query_refs)';
BEGIN
	LOOP
		maybe := try_uri($1, $2, $3, $4, $5);
		IF maybe IS NOT NULL THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with %', this, $1;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO uri_rows(protocol, page, port, tag, query)
			VALUES ($1, $2, uri_port_from_value($3), $4, $5);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % % % % raised %!',
					this, $1, $2, $3, $4, $5, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

-- the idea with this exception rigamarole is to
-- undo the creation of any of the components
-- if they can't all be created.
CREATE OR REPLACE
FUNCTION try_get_uri(text) RETURNS uri_refs AS $$
DECLARE
	part text[] := try_uri_match($1);
	maybe uri_refs;
BEGIN
	IF part IS NULL THEN RETURN NULL; END IF;
	BEGIN
		SELECT into maybe try_get_uri(
			part[1],									-- protocol?
			try_get_page_uri(
				try_get_uri_entity_pair(part[2], part[3]),
				try_get_uri_domain_name(part[4]::citext),
				try_get_uri_path_name(part[6])
			),
			CASE WHEN part[5] = '' THEN 0 ELSE part[5]::int END, -- port?
			part[7],									-- tag?
			try_get_uri_query(part[8])
		);
		IF maybe IS NULL THEN
			RAISE no_data_found;
		END IF;
	EXCEPTION
		WHEN no_data_found THEN RETURN NULL;
	END;
	RETURN maybe;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_uri(text) RETURNS uri_refs AS $$
	SELECT non_null(
		try_get_uri($1), 'get_uri(text)'
	)
$$ LANGUAGE sql;

-- ** uri_refs classes declarations

SELECT type_class_in('uri_refs', 'uri_rows', 'try_uri(text)');

SELECT type_class_out('uri_refs', 'uri_rows', 'uri_text(uri_refs)');

SELECT type_class_op_method(
	'uri_refs', 'uri_rows',
	'ref_text_op(refs)', 'uri_text(uri_refs)'
);

-- * uri_query_values

CREATE OR REPLACE
FUNCTION uri_query_values(uri_refs, text) RETURNS SETOF text AS $$
	SELECT uri_query_values(query, $2) FROM uri_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_uri_query_value(uri_refs, text) RETURNS text AS $$
	SELECT uri_query_values($1, $2) LIMIT 1
$$ LANGUAGE SQL;

DROP OPERATOR IF EXISTS ^ (uri_refs, text) CASCADE;

CREATE OPERATOR ^ (
		leftarg = uri_refs,
		rightarg = text,
		procedure = try_uri_query_value
);
