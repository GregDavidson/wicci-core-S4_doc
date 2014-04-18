-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('doc-test-too.sql', '$Id');

--	Wicci Project Doc_Refs Tests

-- ** Copyright

--	Copyright (c) 2005, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

\set ECHO all

-- SELECT spx_debug_set(2);
-- SELECT refs_debug_set(2);
-- SELECT refs_debug_set(3);

-- select refs_debug_on();

SELECT declare_name('root-test-0');

SELECT COALESCE(
	doc_keys_key( 'doc-test-0'),
	doc_keys_key( 'doc-test-0', new_ref_tree_doc( COALESCE(
		doc_node_keys_key('root-test-0'),
		doc_node_keys_key( 'root-test-0', new_ref_tree_node(
			show1_kind('root-test-0'::name_refs)
		) )
	) ) )
);

SELECT test_func(
	'new_ref_tree_doc(doc_node_refs)',
	tree_doc_text( doc_keys_key( 'doc-test-0') ),
	$$root-test-0$$
);

-- SELECT refs_debug_set(2);

-- SELECT
-- 	ref_id(hold_ref_graft_node('root-test-0-foo',
-- 		hold_doc_node('root-test-0'),
-- 		show1_kind('root-test-0-foo'::text::name_refs)
-- ));

-- SELECT hold_doc_node('root-test-0-foo');

-- SELECT ref_textout(hold_doc_node('root-test-0'));

-- SELECT ref_textout(hold_doc_node('root-test-0-foo'));

-- SELECT ref_id(  hold_ref_changeset_doc(
-- 	'root-test-0-foo',
-- 	hold_ref_doc('doc-test-0'),
-- 	hold_doc_node('root-test-0-foo')
-- ));

-- SELECT test_func(
-- 	'changeset_doc(doc_refs, doc_node_refs[])',
-- 	hold_ref_doc( 'root-test-0-foo')::text,
-- 	$$root-test-0-foo$$
-- );

-- SELECT test_func(
--   'changeset_doc(doc_refs, doc_node_refs[])',
--   hold_ref_changeset_doc(
--     'root-test-0-foo',
--     hold_ref_doc('doc-test-0'),
--     hold_doc_node('root-test-0-foo')
--   )::text,
--   $$root-test-0-foo$$
-- );

SELECT declare_name('root-test-0-foo');

SELECT test_func(
	'graft_node(doc_node_refs, doc_node_kind_refs, doc_node_refs[])',
	graft_node_text( COALESCE(
		doc_node_keys_key('root-test-0-foo'),
		doc_node_keys_key( 'root-test-0-foo',
			graft_node(
				doc_node_keys_key('root-test-0'),
				show1_kind('root-test-0-foo'::name_refs)
			)
		)
	) ),
	$$root-test-0-foo$$
);

SELECT test_func(
	'changeset_doc(doc_refs, doc_node_refs[])',
	changeset_doc_text( COALESCE(
		doc_keys_key('root-test-0-foo'),
		doc_keys_key('root-test-0-foo',
			changeset_doc(
				doc_keys_key('doc-test-0'),
				doc_node_keys_key('root-test-0-foo')
			)
		)
	) ),
	$$root-test-0-foo$$
);

-- SELECT refs_debug_set(1);

SELECT declare_name('root-test-1', '1', '2', '2.1', '3', '3.1', '3.1.1');

CREATE OR REPLACE
FUNCTION unindent(text) RETURNS text AS $$
	SELECT regexp_replace($1, E'\n[[:space:]]*', '', 'g')
$$ LANGUAGE SQL;


SELECT test_func(
	'new_ref_tree_node(doc_node_kind_refs, doc_node_refs[])',
	unindent( tree_doc_text( COALESCE(
		doc_keys_key( 'doc-test-1'),
		doc_keys_key( 'doc-test-1', new_ref_tree_doc( COALESCE(
			doc_node_keys_key('root-test-1'),
			doc_node_keys_key( 'root-test-1', new_ref_tree_node(
				show1_kind('root-test-1'::name_refs),
				doc_node_keys_key( '1', new_ref_tree_node(
					show1_kind(find_name('1'))
				) ),
				doc_node_keys_key( '2', new_ref_tree_node(
					show1_kind(find_name('2')),
					doc_node_keys_key( '2.1', new_ref_tree_node(
						show1_kind(find_name('2.1'))
					) )
				) ),
				doc_node_keys_key('3', new_ref_tree_node(
					show1_kind(find_name('3')),
					doc_node_keys_key('3.1', new_ref_tree_node(
						show1_kind(find_name('3.1')),
						doc_node_keys_key( '3.1.1', new_ref_tree_node(
							show1_kind(find_name('3.1.1'))
						) )
					) )
				) )
			) )
		) ) )
	) ) ),
	unindent( $$root-test-1
 1
 2
  2.1
 3
  3.1
   3.1.1$$
	)
);

-- SELECT COALESCE(
-- 	doc_keys_key( 'doc-test-1'),
-- 	( SELECT doc_keys_key( 'doc-test-1', COALESCE(
-- 		doc_node_keys_key('root-test-1'),
-- 		doc_node_keys_key( new_ref_tree_node(0, ref_root, ref_root,
-- 			show1_kind('root-test-1'::name_refs),
-- 			doc_node_keys_key( '1', new_ref_tree_node(
-- 				1, ref_root, next_doc_node_ref( 'tree_doc_node_rows' ),
-- 				show1_kind('1'::name_refs)
-- 			) ),
-- 			( SELECT doc_node_keys_key( new_ref_tree_node(
-- 				2, ref_root, ref_2, show1_kind('2'::name_refs),
-- 				doc_node_keys_key( '2.1', new_ref_tree_node(
-- 					1, ref_root, next_doc_node_ref( 'tree_doc_node_rows' ),
-- 					show1_kind('2.1'::name_refs)
-- 				) )
-- 			) FROM tree_ref() ref_2 ) ),
-- 			( SELECT  doc_node_keys_key('3', new_ref_tree_node(
-- 				3, ref_root, ref_3, show1_kind('3'::name_refs),
-- 				( SELECT doc_node_keys_key('3.1', new_ref_tree_node(
-- 					1, ref_3, ref_3_1, ref_3, show1_kind('3.1'::name_refs),
-- 					doc_node_keys_key( '3.1.1', new_ref_tree_node(
-- 						1, ref_3_1, show1_kind('3.1.1'::name_refs)
-- 					) )
-- 				) )	FROM tree_ref() ref_3_1
-- 			) ) FROM tree_ref() ref_3 ) )
-- 	 	) )
-- 	) ) FROM tree_ref() ref_root )
-- );

-- SELECT test_func(
-- 	'tree_doc(doc_node_refs)', COALESCE(
-- 		doc_keys_key( 'doc-test-1'),
-- 		hold_ref_tree_doc(
-- 			'doc-test-1', COALESCE(
-- 				doc_node_keys_key('root-test-1'),
-- 				hold_doc_node_root('root-test-1',
-- 					hold_ref_leaf_node('1',
-- 						hold_ref_tree_node('2', ARRAY[
-- 							hold_ref_leaf_node('2.1')
-- 						],
-- 							hold_ref_tree_node('3', ARRAY[
-- 								hold_ref_tree_node('3.1', ARRAY[
-- 									hold_ref_leaf_node('3.1.1')
-- 								] )
-- 							] )
-- 						)
-- 					)
-- 				)
-- 			)
-- 		)
-- 	)::text,
-- $$root-test-1
--  1
--  2
-- 	2.1
--  3
-- 	3.1
-- 		3.1.1$$
-- );

SELECT declare_name('3.1.foo');

SELECT declare_name('3.1.foo');

SELECT test_func(
	'new_ref_tree_node(doc_node_kind_refs, doc_node_refs[])',
	tree_node_text( COALESCE(
		doc_node_keys_key('3.1.foo'),
		doc_node_keys_key('3.1.foo',
			new_ref_tree_node(
				show1_kind('3.1.foo'::name_refs)
			)
		) --  for grafting
	) ),
	'3.1.foo'
);

SELECT declare_name('3.1.1.foo');

SELECT COALESCE(
	doc_node_keys_key('3.1.1.foo-graft'),
	doc_node_keys_key('3.1.1.foo-graft',
		graft_node(
			doc_node_keys_key('3.1.1'),
			show1_kind('3.1.1.foo'::name_refs)
		)
	)
);

SELECT test_func(
	'changeset_doc(doc_refs, doc_node_refs[])',
	unindent( changeset_doc_text( COALESCE(
		doc_keys_key('root-test-1-foo'),
		doc_keys_key('root-test-1-foo',
			changeset_doc(
				doc_keys_key('doc-test-1'),
				doc_node_keys_key( '3.1.1.foo-graft')
			)
		)
	) ) ),
	unindent( $$root-test-1
 1
 2
  2.1
 3
  3.1
   3.1.1.foo$$
	)
);


SELECT declare_name('3-bar');

SELECT COALESCE(
	doc_node_keys_key('3-bar-graft'),
	doc_node_keys_key('3-bar-graft',
		graft_node(
			doc_node_keys_key('3'),
			show1_kind('3-bar'::name_refs),
			doc_node_keys_key('3.1')
		)
	)
);

-- SELECT hold_doc_node( '3.1.1.foo-graft');

-- SELECT hold_ref_doc('doc-test-1');

-- SELECT refs_debug_set(2);

-- SELECT hold_ref_doc('root-test-1-foobar');

SELECT debug_on('changeset_doc_text(doc_refs, env_refs, crefs)', true);

-- SELECT debug_on('doc_node_keys_row(handles, doc_node_refs)', true);
-- SELECT debug_on('doc_node_keys_row(handles, doc_node_refs)', false);

SELECT test_func(
	'changeset_doc(doc_refs, doc_node_refs[])',
	unindent( changeset_doc_text( COALESCE(
		doc_keys_key('root-test-1-foobar'),
		doc_keys_key('root-test-1-foobar',
			changeset_doc(
				doc_keys_key('doc-test-1'),
				doc_node_keys_key( '3-bar-graft'),
				doc_node_keys_key( '3.1.1.foo-graft')
			)
		)
	) ) ),
	unindent( $$root-test-1
 1
 2
  2.1
 3-bar
  3.1
   3.1.1.foo$$
) );

-- SELECT test_func(
--   'changeset_doc(doc_refs, doc_node_refs[])',
--   hold_ref_changeset_doc(
--   'root-test-2-foobar',
--   hold_ref_doc('doc-test-1'),
--     hold_ref_graft_node( '3-bar-graft',
--       hold_doc_node('3'),
--       show1_kind('3-bar'::text::name_refs), hold_doc_node('3.1')
--     ),
--     hold_doc_node( '3.1.1.foo-graft')
--   )::text,$$root-test-1
--  1
--  2
--   2.1
--  3-bar
--   3.1
--    3.1.1.foo$$
-- );
