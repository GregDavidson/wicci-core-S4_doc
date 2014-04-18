-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('uri-test.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	uri_refs: a ref_xml subtype representing XML URIs

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson, all rights
--	reserved.  Although it is my intention to make this code
--	available under a Free Software license when it is ready, this
--	code is currently not to be copied nor shown to anyone without
--	All other use requires my permission in writing.

-- * clear the decks!!

CREATE OR REPLACE
FUNCTION clear_uri_tables() RETURNS void AS $$
	DELETE FROM uri_rows WHERE non_nil(ref);
	DELETE FROM entity_uri_rows WHERE non_nil(ref);
	DELETE FROM page_uri_rows WHERE non_nil(ref);
	DELETE FROM uri_entity_pair_rows WHERE non_nil(ref);
	DELETE FROM uri_entity_type_name_rows WHERE name_ LIKE 'foo%';
	DELETE FROM uri_query_rows WHERE non_nil(ref);
--	DELETE FROM uri_domain_name_rows WHERE non_nil(ref);
	DELETE FROM uri_path_name_rows WHERE non_nil(ref);
$$ LANGUAGE SQL STRICT;

SELECT clear_uri_tables();

-- * uri_entity_type_name

SELECT test_func(
	'uri_entity_type_name_nil()',
	find_uri_entity_type_name(''),
	uri_entity_type_name_nil()
);

SELECT test_func(
	'find_uri_entity_type_name(citext)', 
	uri_entity_type_name_text('user'),
	'user'
);

SELECT test_func(
	'get_uri_entity_type_name(citext)', 
	uri_entity_type_name_text( get_uri_entity_type_name('fooey') ),
	'fooey'
);

SELECT test_func(
	'uri_entity_type_name_text(uri_entity_type_name_refs)', 
	ref_text_op(find_uri_entity_type_name('user')),
	'user'
);

SELECT test_func(
	'uri_entity_type_name_length(uri_entity_type_name_refs)', 
	ref_length_op(find_uri_entity_type_name('user'))::integer,
	4
);

-- * uri_entity_pair

SELECT test_func(
	'try_uri_entity_pair_match(text)', 
	try_uri_entity_pair_match('greg'),
	ARRAY[''::text, 'greg'::text]
);

SELECT test_func(
	'try_uri_entity_pair_match(text)', 
	try_uri_entity_pair_match('user:greg'),
	ARRAY['user'::text, 'greg'::text]
);

SELECT test_func(
	'uri_entity_pair_nil()',
	get_uri_entity_pair(''),
	uri_entity_pair_nil()
);

SELECT test_func(
	'get_uri_entity_pair(text)', 
	uri_entity_pair_text( get_uri_entity_pair('user:greg') ),
	'user:greg'
);

SELECT test_func(
	'uri_entity_type_name_length(uri_entity_type_name_refs)', 
	ref_length_op(find_uri_entity_pair('user:greg'))::integer,
	9
);

SELECT test_func(
	'get_uri_entity_pair(text)', 
	uri_entity_pair_text( get_uri_entity_pair('foobar:greg') ),
	'foobar:greg'
);

SELECT test_func(
	'uri_entity_type_name(uri_entity_pair_refs)', 
	uri_entity_type_name(find_uri_entity_pair('foobar:greg')),
	uri_entity_type_name_other()
);

SELECT test_func(
	'uri_entity_type_name_length(uri_entity_type_name_refs)', 
	ref_length_op(find_uri_entity_pair('foobar:greg'))::integer,
	11
);

SELECT test_func(
	'uri_entity_pair_text(uri_entity_pair_refs)', 
	ref_text_op(get_uri_entity_pair('greg')),
	'greg'
);

SELECT test_func(
	'uri_entity_pair_length(uri_entity_pair_refs)', 
	ref_length_op(find_uri_entity_pair('greg'))::integer,
	4
);

SELECT test_func(
	'uri_entity_type_name(uri_entity_pair_refs)', 
	uri_entity_type_name(find_uri_entity_pair('greg')),
	uri_entity_type_name_nil()
);

SELECT test_func(
	'uri_entity_type_name(uri_entity_pair_refs)', 
	uri_entity_type_name(find_uri_entity_pair('user:greg')),
	find_uri_entity_type_name('user')
);

-- * uri_query

SELECT test_func(
	'try_uri_query_pair_key(text)',
	try_uri_query_pair_key('color=red'),
	'color'
);

SELECT test_func(
	'try_uri_query_pair_val(text)',
	try_uri_query_pair_val('color=red'),
	'red'
);

SELECT test_func(
	'try_uri_query_pair_key(text)',
	try_uri_query_pair_key('colorful'),
	'colorful'
);

SELECT test_func(
	'try_uri_query_pair_val(text)',
	try_uri_query_pair_val('colorful') IS NULL
);

SELECT test_func(
	'try_uri_query_parse(text)',
	_keys_ = ARRAY['color'::text] AND _vals_ = ARRAY['red'::text]
) FROM try_uri_query_parse('color=red') AS a(_keys_, _vals_);

SELECT test_func(
	'try_uri_query_parse(text)',
	_keys_ = ARRAY['color'::text, 'style'::text]
	AND _vals_ = ARRAY['red'::text, 'bold'::text]
) FROM try_uri_query_parse('color=red&style=bold')
	AS a(_keys_, _vals_);

SELECT test_func(
	'try_uri_query_parse(text)',
	_keys_ = ARRAY['colorful'::text, 'bold'::text]
	AND _vals_ = ARRAY[NULL::text, NULL::text]
) FROM try_uri_query_parse('colorful&bold')
	AS a(_keys_, _vals_);

SELECT test_func(
	'uri_query_nil()',
	find_uri_query(''),
	uri_query_nil()
);

SELECT test_func(
	'get_uri_query(text)',
	uri_query_text( get_uri_query('color=red&style=bold') ),
	'color=red&style=bold'
);
	
SELECT test_func(
	'find_uri_query(text)',
	uri_query_text( find_uri_query('color=red&style=bold') ),
	'color=red&style=bold'
);
	
SELECT test_func(
	'get_uri_query(text)',
	uri_query_text( get_uri_query('colorful&bold') ),
	'colorful&bold'
);

SELECT test_func(
	'find_uri_query(text)',
	uri_query_text( find_uri_query('colorful&bold') ),
	'colorful&bold'
);

-- * uri_domain_name

SELECT test_func(
	'uri_domain_name_nil()',
	find_uri_domain_name(''),
	uri_domain_name_nil()
);

SELECT test_func(
	'get_uri_domain_name(citext)', 
	uri_domain_name_text(get_uri_domain_name('puuhonua.org')),
	'puuhonua.org'
);

SELECT test_func(
	'find_uri_domain_name(citext)', 
	uri_domain_name_text(find_uri_domain_name('puuhonua.org')),
	'puuhonua.org'
);

-- * uri_path_name

SELECT test_func(
	'uri_path_name_nil()',
	get_uri_path_name(''),
	uri_path_name_nil()
);

SELECT test_func(
	'get_uri_path_name(text)', 
	uri_path_name_text(get_uri_path_name('foo/bar')),
	'foo/bar'
);

SELECT test_func(
	'find_uri_path_name(text)', 
	uri_path_name_text(find_uri_path_name('foo/bar')),
	'foo/bar'
);

-- * page_uri

SELECT test_func(
	'page_uri_nil()',
	find_page_uri(''),
	page_uri_nil()
);

SELECT test_func(
	'get_page_uri(text)', 
	page_uri_text(get_page_uri('puuhonua.org')),
	'puuhonua.org'
);

SELECT test_func(
	'get_page_uri(text)', 
	page_uri_text(get_page_uri('/foo/bar')),
	'/foo/bar'
);

SELECT test_func(
	'get_page_uri(text)', 
	page_uri_text(get_page_uri('/foo/bar')),
	'/foo/bar'
);

SELECT test_func(
	'get_page_uri(text)', 
	page_uri_text(get_page_uri('touch@puuhonua.org')),
	'touch@puuhonua.org'
);

SELECT test_func(
	'get_page_uri(text)', 
	page_uri_text(get_page_uri('user:touch@puuhonua.org')),
	'user:touch@puuhonua.org'
);

SELECT test_func(
	'get_page_uri(text)', 
	page_uri_text(
		get_page_uri('user:touch@puuhonua.org/index.html')
	),
	'user:touch@puuhonua.org/index.html'
);

SELECT test_func(
	'get_page_uri(text)', 
	page_uri_text(
		get_page_uri('user:touch@puuhonua.org/index.html')
	),
	'user:touch@puuhonua.org/index.html'
);

SELECT test_func(
	'find_page_uri(text)', 
	page_uri_text(
		find_page_uri('user:touch@puuhonua.org/index.html')
	),
	'user:touch@puuhonua.org/index.html'
);

-- * entity_uri

SELECT test_func(
	'entity_uri_nil()',
	find_entity_uri(''),
	entity_uri_nil()
);

SELECT test_func(
	'entity_uri_nil()',
	get_entity_uri(''),
	entity_uri_nil()
);

SELECT test_func(
	'get_entity_uri(text)', 
	entity_uri_text(get_entity_uri('touch@puuhonua.org')),
	'touch@puuhonua.org'
);

SELECT test_func(
	'get_entity_uri(text)', 
	entity_uri_text(get_entity_uri('user:touch@puuhonua.org')),
	'user:touch@puuhonua.org'
);

SELECT test_func(
	'get_entity_uri(text)', 
	entity_uri_text(
		get_entity_uri('user:touch@puuhonua.org/index.html')
	),
	'user:touch@puuhonua.org/index.html'
);

SELECT test_func(
	'find_entity_uri(text)', 
	entity_uri_text(
		find_entity_uri('user:touch@puuhonua.org/index.html')
	),
	'user:touch@puuhonua.org/index.html'
);

-- * uri

SELECT try_uri_match('puuhonua.org');

SELECT try_uri_match(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
);

SELECT test_func(
	'uri_nil()',
	get_uri(''),
	uri_nil()
);

SELECT test_func(
	'get_uri(text)', 
	uri_text(get_uri('puuhonua.org')),
	'puuhonua.org'
);

SELECT test_func(
	'get_uri(text)', 
	uri_text(get_uri('/foo/bar')),
	'/foo/bar'
);

SELECT test_func(
	'get_uri(text)', 
	uri_text(get_uri('/foo/bar')),
	'/foo/bar'
);

SELECT test_func(
	'get_uri(text)', 
	uri_text(get_uri('touch@puuhonua.org')),
	'touch@puuhonua.org'
);

SELECT test_func(
	'get_uri(text)', 
	uri_text(get_uri('user:touch@puuhonua.org')),
	'user:touch@puuhonua.org'
);

SELECT test_func(
	'get_uri(text)', 
	uri_text(
		get_uri('user:touch@puuhonua.org/index.html')
	),
	'user:touch@puuhonua.org/index.html'
);

SELECT test_func(
	'find_uri(text)', 
	uri_text(
		find_uri('user:touch@puuhonua.org/index.html')
	),
	'user:touch@puuhonua.org/index.html'
);

-- * clear the decks!!

-- SELECT clear_uri_tables();		-- ???

\q
-- HERE

CREATE OR REPLACE
FUNCTION uri_test_uri_array() RETURNS text[] AS $$
	SELECT ARRAY[
'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'::text,
'user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'::text,
'user:touch@puuhonua.org/foo/bar#baz?up=down,x=0'::text,
'touch@puuhonua.org/foo/bar#baz?up=down,x=0'::text,
'user:@puuhonua.org/foo/bar#baz?up=down,x=0'::text,
'puuhonua.org/foo/bar#baz?up=down,x=0'::text,
'puuhonua.org/foo/bar'::text,
'puuhonua.org'::text,
'user:touch@puuhonua.org'::text
]
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION uri_test_uris() RETURNS SETOF text AS $$
	SELECT uri FROM unnest(uri_test_uri_array()) uri
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION uri_test_uri() RETURNS text AS $$
	SELECT (uri_test_uri_array())[1]
$$ LANGUAGE SQL IMMUTABLE;

SELECT
	test_func( 'get_uri(text)', uri_text(get_uri(uri)), uri)
FROM uri_test_uris() uri;

SELECT test_func(
	'uri_core_array(uri_refs)',
	uri_core_array(_uri),
	ARRAY['org', 'puuhonua', '', 'foo', 'bar']
) FROM get_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) _uri;

SELECT test_func(
	'uri_full_array(uri_refs)',
	uri_full_array(_uri),
	ARRAY['org', 'puuhonua', '', 'foo', 'bar', 'user:', 'touch']
) FROM get_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) _uri;

SELECT test_func(
	'uri_core_text(uri_refs)',
	uri_core_text(_uri),
	'puuhonua.org/foo/bar'::text
) FROM get_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) _uri;

SELECT test_func(
	'uri_full_text(uri_refs)',
	uri_full_text(_uri),
	'user:touch@puuhonua.org/foo/bar'::text
) FROM get_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) _uri;

SELECT test_func(
	'uri_core_depth(uri_refs)',
	uri_core_depth(_uri),
	5
) FROM get_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) _uri;

SELECT uri_domain_name_end_(_uri), uri_path_name_end(_uri)
FROM get_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) _uri;

SELECT domain_, path_
FROM uri_rows WHERE ref = try_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
);

SELECT test_func(
	'uri_full_depth(uri_refs)',
	uri_full_depth(_uri),
	7
) FROM get_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) _uri;

SELECT uri_full_array( get_uri(
	'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) );


SELECT uri_full_array( get_uri(
		'http://user:@puuhonua.org:80/foo/bar#baz?up=down,x=0'
) );

SELECT nuri, entity_ IS NULL, entity_
FROM uri_rows WHERE ref = try_uri(
	'http://user:@puuhonua.org:80/foo/bar#baz?up=down,x=0'
);


SELECT test_func(
	'uri_common_depth(uri_refs, uri_refs)',
	uri_common_depth(
		get_uri(
			'http://user:touch@puuhonua.org:80/foo/bar#baz?up=down,x=0'
		),
		get_uri(
			'http://user:@puuhonua.org:80/foo/bar#baz?up=down,x=0'
		)
	),
	6
);

SELECT test_func(
	'find_page_uri(text)',
	find_page_uri('puuhonua.org')::uri_refs,
	try_uri('puuhonua.org/')
);

SELECT spx_debug_set(3);

SELECT refs_debug_set(3);

SELECT test_func(
	'get_page_uri(text)',
	ref_text_op( get_page_uri('puuhonua.org/page-path')::refs ),
	'puuhonua.org/page-path'::text
);

SELECT refs_debug_off();
SELECT spx_debug_off();

SELECT test_func(
	'find_entity_uri(text)',
	find_entity_uri('user:touch@puuhonua.org')::uri_refs,
	try_uri('user:touch@puuhonua.org')
);

SELECT test_func(
	'get_entity_uri(text)',
	ref_text_op( get_entity_uri('user:touch@puuhonua.org')::refs ),
	'user:touch@puuhonua.org'::text
);

SELECT test_func(
	'get_email_uri(text)',
	ref_text_op( get_email_uri('touch@puuhonua.org')::refs ),
	'touch@puuhonua.org'::text
);

SELECT test_func(
	'find_email_uri(text)',
	find_email_uri('touch@puuhonua.org')::uri_refs,
	try_uri('touch@puuhonua.org')
);
