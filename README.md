# Directory: Wicci/Core/S3_more

## This project is dependent on

* [Wicci Core, C_lib, S0_lib](https://github.com/GregDavidson/wicci-core-S0_lib)
* [Wicci S1_refs](https://github.com/GregDavidson/wicci-core-S1_refs)
* [Wicci S2_core](https://github.com/GregDavidson/wicci-core-S2_core)
* [Wicci S3_more](https://github.com/GregDavidson/wicci-core-S3_more)

## Wicci Support for Hierarchical Documents & Uniform Resource Identifiers

### Reference Types Implemented In This Schema

| Type	| References
|-----------------------|----------
| doc_refs	| a hierarchical document
| doc_node_refs	|  a node of a hierarchical document
| doc_node_kind_refs	| some kind of data associated with a node
| text_blob_kind_refs	| some bytes (possibly large, possibly text or binary) kind
| uri_refs	| fully general uri type
| entity_uri_refs	| uri of an entity
| uri_entity_pair_refs	| type:name@
| uri_query_refs	| ?v1=foo,v2=bar
| page_uri_refs	| a uri of a web page
| doc_page_refs	| doc_refs paired with page_uri_refs
