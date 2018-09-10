val not_yet_implemented_because : string -> string -> 'a
val impossible_because : string -> string -> 'a
val impossible_with_heap_because : string -> JsSyntax.state -> string -> 'a
val impossible_resvalue : string -> JsSyntax.resvalue -> string -> 'a
val ref_get_value : JsSyntax.ref -> unit
val ref_get_value_2 : JsSyntax.resvalue -> unit
val run_object_method : JsSyntax.object_loc -> unit
val run_object_heap_set_extensible : JsSyntax.object_loc -> unit
val lexical_env_get_identifier_ref : string -> unit
