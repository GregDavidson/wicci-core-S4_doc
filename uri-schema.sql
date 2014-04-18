-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('uri-schema.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	ref-types for representing xml uris

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- TO DO:
-- finish testing current and remaining code
-- add private path function(s)
-- add intersection function(s) and operator(s)
-- be sure to test strings which should normalize to the same uri!
-- tighten uri_pattern
-- register additional operations?

-- CGI_ENCODED_URI issue:
-- -- Currently any encoded parts of the uri are stored that way
-- -- Any part of a URI as a value must be wrapped in str_cgi_decode
-- Alternatively:
-- -- use str_cgi_decode when internalizing a uri, and then
-- -- use str_cgi_encode (does not yet exist!) when rendering as text

-- * three different kinds of uri_refs

SELECT create_ref_type('uri_refs'); -- fully general uri type
SELECT create_ref_type('page_uri_refs'); -- uri of a web page
SELECT create_ref_type('entity_uri_refs'); -- uri of an entity

DROP CAST IF EXISTS (page_uri_refs AS uri_refs) CASCADE;
CREATE CAST (page_uri_refs AS uri_refs)
	WITHOUT FUNCTION AS IMPLICIT;

DROP CAST IF EXISTS (entity_uri_refs AS uri_refs) CASCADE;
CREATE CAST (entity_uri_refs AS uri_refs)
	WITHOUT FUNCTION AS IMPLICIT;

-- * uri_entity_type_name

-- SELECT create_name_ref_schema(
-- 	'uri_entity_type_name', _norm := 'str_trim_lower(text)'
-- );
SELECT create_name_ref_schema(
	'uri_entity_type_name', name_type := 'citext'
);

-- CREATE TABLE IF NOT EXISTS uri_entity_type_name_rows (
-- 	ref uri_entity_type_name_refs PRIMARY KEY,
-- 	name_ text NOT NULL
-- );

COMMENT ON COLUMN uri_entity_type_name_rows.name_
IS 'Special values:
1. "" - no type specified
2 "_" - unknown type, actual type will prefix the entity name.';

-- ** id management

CREATE OR REPLACE FUNCTION uri_entity_type_name_other()
RETURNS uri_entity_type_name_refs AS $$
	SELECT unchecked_uri_entity_type_name_from_id(-1)
$$ LANGUAGE SQL IMMUTABLE;

INSERT INTO uri_entity_type_name_rows(ref, name_) VALUES
--	( uri_entity_type_name_nil(), '' ),
	( uri_entity_type_name_other(), '_' );

-- * uri_entity_pair

SELECT create_ref_type('uri_entity_pair_refs'); -- type:name@

CREATE TABLE IF NOT EXISTS uri_entity_pair_rows (
	ref uri_entity_pair_refs PRIMARY KEY,
  type_ uri_entity_type_name_refs NOT NULL,
	name_ text NOT NULL,
	UNIQUE(type_, name_)
);

COMMENT ON TABLE uri_entity_pair_rows IS
'represents the entity_type_name:entity_name@...
at the beginning of some uris';
COMMENT ON COLUMN uri_entity_pair_rows.name_ IS
'When type_ is "_" then value';

SELECT declare_ref_class_with_funcs('uri_entity_pair_rows');
SELECT create_simple_serial('uri_entity_pair_rows');

INSERT INTO uri_entity_pair_rows(ref, type_, name_)
VALUES (uri_entity_pair_nil(), uri_entity_type_name_nil(), '');

-- * uri_query

SELECT create_ref_type('uri_query_refs'); -- ?v1=foo,v2=bar

CREATE TABLE IF NOT EXISTS uri_query_rows (
	ref uri_query_refs PRIMARY KEY,
  keys text[] NOT NULL,
	vals text[] NOT NULL,
	CHECK(
		array_lower(keys, 1) IS NOT DISTINCT FROM array_lower(vals, 1)
	),
	CHECK(
		array_upper(keys, 1) IS NOT DISTINCT FROM array_upper(vals, 1)
	),
	UNIQUE(keys, vals)
);

COMMENT ON TABLE uri_query_rows IS
'represents the possible ?key1=value1&key2-value2&...
query list which can be at the end of a uri.
The ^ operator will be overloaded to be able to
look up values assoc
ALSO: Used to represent cookie values in incoming
HTTP requests!!
';

SELECT declare_ref_class_with_funcs('uri_query_rows');
SELECT create_simple_serial('uri_query_rows');

INSERT INTO uri_query_rows(ref, keys, vals)
VALUES (uri_query_nil(), '{}'::text[], '{}'::text[]);

-- * uri_domain_name

CREATE OR REPLACE
FUNCTION uri_domain_name_normalized(text) RETURNS text AS $$
	SELECT x FROM lower( regexp_replace(
		trim(BOTH '.' FROM regexp_replace($1, '[[:space:]]', '', 'g')),
		E'\\.\\.+', '.', 'g'
	) ) x WHERE x <> ''
$$ LANGUAGE SQL;

COMMENT ON FUNCTION uri_domain_name_normalized(text)
IS 'Maybe further normalize and check domain text???';

SELECT create_name_ref_schema(
	'uri_domain_name',
	name_type := 'citext',
	_norm := 'uri_domain_name_normalized(text)',
	_:= 'represents an internet domain, e.g. www.wicci.org'
);

-- CREATE TABLE IF NOT EXISTS uri_domain_name_rows (
-- 	ref uri_domain_name_refs PRIMARY KEY,
-- 	name_ TEXT NOT NULL UNIQUE
-- );

COMMENT ON COLUMN uri_domain_name_rows.name_ IS '
	Case insensitive.  Least to most significant.  Uses "." delmiter.
	How should these be normalized??
';

-- * uri_path_name

CREATE OR REPLACE
FUNCTION uri_path_name_normalized(text) RETURNS text AS $$
	SELECT x FROM regexp_replace(
		trim(BOTH '/' FROM regexp_replace($1, '[[:space:]]', '', 'g')),
		'//+', '/', 'g'
	) x WHERE x <> ''
$$ LANGUAGE SQL;

COMMENT ON FUNCTION uri_path_name_normalized(text)
IS 'Maybe further normalize and check path text???';

SELECT create_name_ref_schema(
	'uri_path_name',
	_norm := 'uri_path_name_normalized(text)',
	_:= 'represents a file path, e.g. /public/index.html'
);
-- CREATE TABLE IF NOT EXISTS uri_path_name_rows (
-- 	ref uri_path_name_refs PRIMARY KEY,
-- 	name_ TEXT NOT NULL UNIQUE
-- );

COMMENT ON COLUMN uri_path_name_rows.name_ IS '
	Case sensitive.  Most to least significant.  Uses "/" delmiter.
	How should these be normalized??
';

-- * page_uri

CREATE TABLE IF NOT EXISTS page_uri_rows (
	ref page_uri_refs PRIMARY KEY,
	entity_ uri_entity_pair_refs NOT NULL
		REFERENCES uri_entity_pair_rows,
	domain_ uri_domain_name_refs NOT NULL
		REFERENCES uri_domain_name_rows,
	path_ uri_path_name_refs NOT NULL REFERENCES uri_path_name_rows,
	UNIQUE(entity_, domain_, path_)
);

COMMENT ON TABLE page_uri_rows IS '
	Uniquely represents a web page with a unique
	combination of domain and path.';
COMMENT ON COLUMN page_uri_rows.entity_
IS 'is_nil(domain_) means no entity in this uri.';
COMMENT ON COLUMN page_uri_rows.domain_
IS 'is_nil(domain_) means no domain in this uri.';
COMMENT ON COLUMN page_uri_rows.path_
IS 'is_nil(path_) means no path in this uri.  Do these
paths begin with a / or not?  How else should they be
normalized?';

SELECT declare_ref_class_with_funcs('page_uri_rows');
SELECT create_simple_serial('page_uri_rows');

CREATE OR REPLACE FUNCTION page_uri_entity(page_uri_refs)
RETURNS uri_entity_pair_refs AS $$
	SELECT entity_ FROM page_uri_rows WHERE ref = $1
$$ LANGUAGE SQL;

INSERT INTO page_uri_rows(ref, entity_, domain_, path_) VALUES (
	page_uri_nil(), uri_entity_pair_nil(),
	uri_domain_name_nil(), uri_path_name_nil()
);

-- * entity_uri

CREATE TABLE IF NOT EXISTS entity_uri_rows (
	ref entity_uri_refs PRIMARY KEY,
	page page_uri_refs UNIQUE NOT NULL REFERENCES page_uri_rows
		CHECK(is_nil(page) OR non_nil(page_uri_entity(page))),
	CHECK(ref_id(ref) = ref_id(page))
);

COMMENT ON TABLE entity_uri_rows IS '
	Uniquely represents a typed entity assocociated
	with a uri domain and path.  entity_uri_refs can
	be cast into page_uri_refs.
	I intend allowing entity_uri_rows to be implicitly
	cast into page_uri_refs to allow special web pages
	which display entity information!!
	';
COMMENT ON COLUMN entity_uri_rows.ref
IS 'Re-usses same id as pre-existing page.';

SELECT declare_ref_class_with_funcs('entity_uri_rows');

INSERT INTO entity_uri_rows(ref, page)
VALUES ( entity_uri_nil(), page_uri_nil() );

-- * uri

CREATE OR REPLACE
FUNCTION uri_port_to_value(int) RETURNS int AS $$
	SELECT $1 - _offset FROM CAST(- 2^15 AS integer) _offset
	WHERE $1 >= _offset
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION uri_port_from_value(int) RETURNS int AS $$
	SELECT $1 - _offset FROM CAST(2^15 AS integer) _offset
	WHERE $1 >= 0 AND $1 < _offset + _offset - 1
$$ LANGUAGE SQL;

CREATE TABLE IF NOT EXISTS uri_rows (
	ref uri_refs PRIMARY KEY,
	protocol text NOT NULL DEFAULT '',
	page page_uri_refs NOT NULL REFERENCES page_uri_rows,
	port smallint NOT NULL DEFAULT uri_port_from_value(0),
	tag text NOT NULL DEFAULT '',
	query uri_query_refs NOT NULL REFERENCES uri_query_rows,
	UNIQUE(page, protocol, port, tag, query)
);

COMMENT ON TABLE uri_rows IS
'Uniquely represents a general uri which has some
features beyond those of a page_uri.';
COMMENT ON COLUMN uri_rows.port
IS 'Unsigned value in signed 16-bit field offset by 2^15
with functions: uri_port_to_value, uri_port_from_value';
COMMENT ON COLUMN uri_rows.tag
IS 'empty means none specified';

SELECT declare_ref_class_with_funcs('uri_rows');
SELECT create_simple_serial('uri_rows');

INSERT INTO uri_rows(ref, page, query)
VALUES ( uri_nil(), page_uri_nil(), uri_query_nil() );


