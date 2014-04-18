-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('doc-test.sql', '$Id$');

--	Wicci Project s4_doc Tests

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

\set ECHO all

-- SELECT spx_debug_set(2);
-- SELECT refs_debug_set(2);
-- SELECT ctext_debug_set(2);

-- select refs_debug_on();

-- * doc tests

-- ** create and test a document tree with one node

SELECT declare_name('doc-1-root');

SELECT COALESCE(
	doc_keys_key('doc-1'),
	doc_keys_key('doc-1', new_tree_doc( COALESCE(
		doc_node_keys_key('doc-1-root'),
		doc_node_keys_key( 'doc-1-root', new_tree_node(
			show1_kind('doc-1-root'::name_refs)
		) )
	) ) )
);

SELECT test_func(
	'new_tree_doc(doc_node_refs,doc_lang_name_refs)',
	tree_doc_text( doc_keys_key( 'doc-1') ),
	$$doc-1-root$$
);

-- ** create and test a graft node and changeset document

SELECT declare_name('doc-1-root-graft');

SELECT test_func(
	'graft_node(doc_node_refs, doc_node_kind_refs, doc_node_refs[])',
	graft_node_text( COALESCE(
		doc_node_keys_key('doc-1-root-graft'),
		doc_node_keys_key( 'doc-1-root-graft',
			graft_node(
				doc_node_keys_key('doc-1-root'),
				show1_kind('doc-1-root-graft'::name_refs)
			)
		)
	) ),
	$$doc-1-root-graft$$
);

SELECT test_func(
	'get_changeset_doc(doc_refs, doc_node_refs[])',
	changeset_doc_text( COALESCE(
		doc_keys_key('doc-1-root-graft'),
		doc_keys_key('doc-1-root-graft',
			get_changeset_doc(
				doc_keys_key('doc-1'),
				doc_node_keys_key('doc-1-root-graft')
			)
		)
	) ),
	$$doc-1-root-graft$$
);

-- SELECT refs_debug_set(1);

-- ** create and test a three-level document tree

SELECT declare_name('doc-3-root', '1', '2', '2.1', '3', '3.1', '3.1.1');

SELECT test_func_tokens(
	'new_tree_node(doc_node_kind_refs, doc_node_refs[])',
	tree_doc_text( COALESCE(
		doc_keys_key( 'doc-3'),
		doc_keys_key( 'doc-3', new_tree_doc( COALESCE(
			doc_node_keys_key('doc-3-root'),
			doc_node_keys_key( 'doc-3-root', new_tree_node(
				show1_kind('doc-3-root'::name_refs),
				doc_node_keys_key( '1', new_tree_node(
					show1_kind(find_name('1'))
				) ),
				doc_node_keys_key( '2', new_tree_node(
					show1_kind(find_name('2')),
					doc_node_keys_key( '2.1', new_tree_node(
						show1_kind(find_name('2.1'))
					) )
				) ),
				doc_node_keys_key('3', new_tree_node(
					show1_kind(find_name('3')),
					doc_node_keys_key('3.1', new_tree_node(
						show1_kind(find_name('3.1')),
						doc_node_keys_key( '3.1.1', new_tree_node(
							show1_kind(find_name('3.1.1'))
						) )
					) )
				) )
			) )
		) ) )
	) ),
$$doc-3-root
 1
 2
  2.1
 3
  3.1
   3.1.1$$
);

-- ** create and test some grafts and a changset on the larger tree

SELECT declare_name('3.2-new');

SELECT test_func(
	'new_tree_node(doc_node_kind_refs, doc_node_refs[])',
	tree_node_text( COALESCE(
		doc_node_keys_key('3.2'),
		doc_node_keys_key('3.2',
			new_tree_node(
				show1_kind('3.2-new'::name_refs)
			)
		) --  for grafting
	) ),
	'3.2-new'
);

SELECT declare_name('3.1.1-graft');

SELECT COALESCE(
	doc_node_keys_key('3.1.1-graft'),
	doc_node_keys_key('3.1.1-graft',
		graft_node(
			doc_node_keys_key('3.1.1'),
			show1_kind('3.1.1-graft'::name_refs)
		)
	)
);

SELECT test_func_tokens(
	'get_changeset_doc(doc_refs, doc_node_refs[])',
	changeset_doc_text( COALESCE(
		doc_keys_key('doc-3-root-graft'),
		doc_keys_key('doc-3-root-graft',
			get_changeset_doc(
				doc_keys_key('doc-3'),
				doc_node_keys_key( '3.1.1-graft')
			)
		)
	) ),
	$$doc-3-root
 1
 2
  2.1
 3
  3.1
   3.1.1-graft$$
);


SELECT declare_name('3-graft');

SELECT COALESCE(
	doc_node_keys_key('3-graft'),
	doc_node_keys_key('3-graft',
		graft_node(
			doc_node_keys_key('3'),
			show1_kind('3-graft'::name_refs),
			doc_node_keys_key('3.1'),
			doc_node_keys_key('3.2')
		)
	)
);

-- SELECT debug_on('changeset_doc_text(doc_refs, env_refs, crefs)', true);

-- SELECT debug_on('doc_node_keys_row(handles, doc_node_refs)', true);
-- SELECT debug_on('doc_node_keys_row(handles, doc_node_refs)', false);

SELECT test_func_tokens(
	'get_changeset_doc(doc_refs, doc_node_refs[])',
	changeset_doc_text( COALESCE(
		doc_keys_key('doc-3-root-2grafts'),
		doc_keys_key('doc-3-root-2grafts',
			get_changeset_doc(
				doc_keys_key('doc-3'),
				doc_node_keys_key( '3-graft'),
				doc_node_keys_key( '3.1.1-graft')
			)
		)
	) ),
	$$doc-3-root
 1
 2
  2.1
 3-graft
  3.1
   3.1.1-graft
  3.2-new$$
);

-- * matching tests

CREATE OR REPLACE
FUNCTION all_graft_nodes() RETURNS doc_node_refs[] AS $$
  SELECT ARRAY(SELECT ref FROM graft_doc_node_rows)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION test_match_grafts_first(
  handles, grafts doc_node_refs[] = all_graft_nodes()
) RETURNS doc_node_refs AS $$
   SELECT match_grafts_first_( doc_node_keys_key($1), $2 );
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION test_match_grafts_left(
  handles, grafts doc_node_refs[] = all_graft_nodes()
) RETURNS doc_node_refs[] AS $$
   SELECT match_grafts_left_( doc_node_keys_key($1), $2 );
$$ LANGUAGE sql;

-- ALL THIS CODE NEEDS TO BE AUTOMATICALLY TESTED!!!

SELECT *, doc_node_text(ref) FROM abstract_doc_node_rows
WHERE ref = test_match_grafts_first('3.1.1');

SELECT *, doc_node_text(ref) FROM graft_doc_node_rows
WHERE origin = doc_node_keys_key('3.1.1');

SELECT ref, doc_node_text(ref)
FROM
	abstract_doc_node_rows an,
	unnest(all_graft_nodes()) gn
WHERE an.ref = gn;

SELECT ref, doc_node_text(ref)
FROM
	abstract_doc_node_rows an,
	unnest(test_match_grafts_left('3.1.1')) gn
WHERE an.ref = gn;


SELECT node, doc_node_text(node)
FROM doc_node_keys_key('1') node;

SELECT *, doc_node_text(ref)
FROM graft_doc_node_rows
WHERE origin = doc_node_keys_key('1');

SELECT *, doc_node_text(ref)
FROM abstract_doc_node_rows
WHERE ref = test_match_grafts_first('1');

SELECT ref, doc_node_text(ref)
FROM
	abstract_doc_node_rows an,
	unnest(all_graft_nodes()) gn
WHERE an.ref = gn;

SELECT ref, doc_node_text(ref)
FROM
	abstract_doc_node_rows an,
	unnest(test_match_grafts_left('1')) gn
WHERE an.ref = gn;

SELECT ref, doc_node_text(ref)
FROM match_grafts_first_(
	doc_node_keys_key('3.1.1'), all_graft_nodes()
) ref;

SELECT ref, doc_node_text(ref)
FROM unnest(
	match_grafts_left_(doc_node_keys_key('3.1.1'), all_graft_nodes())
) ref;

SELECT ref, doc_node_text(ref)
FROM match_grafts_first_(
	doc_node_keys_key('3.1.1'), no_doc_node_array()
) ref;

SELECT ref, doc_node_text(ref)
FROM match_grafts_first_(
	doc_node_keys_key('doc-3-root'), no_doc_node_array()
) ref;

SELECT ref, doc_node_text(ref)
FROM doc_node_keys_key('doc-3-root') ref;

SELECT array_is_empty('{}'::integer[]);

SELECT ref, doc_node_text(ref)
FROM find_by_path(
	doc_node_keys_key('doc-3-root'), '{}'::integer[]
) ref;

SELECT ref, doc_node_text(ref)
FROM find_by_path(
	doc_node_keys_key('doc-3-root'), '{}'::integer[], all_graft_nodes()
) ref;

SELECT ref, doc_node_text(ref)
FROM find_by_path(
	doc_node_keys_key('doc-3-root'), ARRAY[1]
) ref;

SELECT ref, doc_node_text(ref)
FROM find_by_path(
	doc_node_keys_key('doc-3-root'), ARRAY[1], all_graft_nodes()
) ref;

SELECT ref, doc_node_text(ref)
FROM find_by_path(
	doc_node_keys_key('doc-3-root'), ARRAY[1]
) ref;

SELECT ref, doc_node_text(ref)
FROM find_by_path(
	doc_node_keys_key('doc-3-root'), ARRAY[1], all_graft_nodes()
) ref;


SELECT ref, doc_node_text(ref)
FROM unnest(test_match_grafts_left('3.1.1')) ref;

SELECT handle, ref, doc_node_text(ref)
FROM doc_node_keys_row_handles, graft_doc_node_rows
WHERE key = origin;

SELECT handle, ref, doc_node_text(ref)
FROM doc_node_keys_row_handles, tree_doc_node_rows
WHERE key = ref;

SELECT array_length(
	ARRAY(SELECT ref FROM graft_doc_node_rows)
);

SELECT *, doc_node_text(ref) FROM graft_doc_node_rows
WHERE ref = match_grafts_first_(
  doc_node_keys_key('doc-1-root'),
	ARRAY(SELECT ref FROM graft_doc_node_rows)
);

SELECT *, doc_node_text(ref) FROM tree_doc_node_rows
WHERE ref = match_grafts_first_(
  doc_node_keys_key('1'),
	ARRAY(SELECT ref FROM graft_doc_node_rows)
);

SELECT *, doc_node_text(ref) FROM graft_doc_node_rows
WHERE ref = match_grafts_first_(
  doc_node_keys_key('3.1.1'),
	ARRAY(SELECT ref FROM graft_doc_node_rows)
);

SELECT  array_length( ARRAY(SELECT ref FROM graft_doc_node_rows) );

SELECT * FROM
	graft_doc_node_rows,
	unnest( match_grafts_left_(
		doc_node_keys_key('3.1.1'),
		ARRAY(SELECT ref FROM graft_doc_node_rows)
	) ) x
WHERE ref = x;

SELECT *, doc_node_text(ref) FROM graft_doc_node_rows
WHERE ref = match_grafts_first_(
  doc_node_keys_key('3.1.1'),
  match_grafts_left_(
		doc_node_keys_key('3.1.1'),
		ARRAY(SELECT ref FROM graft_doc_node_rows)
	)
);

SELECT *, doc_node_text(ref) FROM graft_doc_node_rows
WHERE ref = ANY( match_grafts_left_(
  doc_node_keys_key('3.1.1'),
	ARRAY(SELECT ref FROM graft_doc_node_rows)
) );

/*
-- no function doc_node_matches !!
-- what was the original intent ??
SELECT ref, doc_node_text(ref)
FROM doc_node_matches(
	doc_node_keys_key('3.1.1'),
	ARRAY(SELECT ref FROM graft_doc_node_rows)
) ref;
*/

/*
-- no function doc_node_match !!
-- what was the original intent ??
SELECT ref, doc_node_text(ref)
FROM doc_node_match(
	doc_node_keys_key('3'),
	ARRAY(SELECT ref FROM graft_doc_node_rows)
) ref;

SELECT doc_node_match(
	doc_node_keys_key('xyzzy'),
	ARRAY(SELECT ref FROM graft_doc_node_rows)
) IS NULL;
*/

SELECT array_length( match_grafts_left_(
	doc_node_keys_key('3.1.1'),
	ARRAY(SELECT ref FROM graft_doc_node_rows)
) );
