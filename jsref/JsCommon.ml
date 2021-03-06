
open Datatypes
(*open JsNumber*)
open JsSyntax
open JsSyntaxAux
open LibList
open LibOption
open Shared

(** val res_overwrite_value_if_empty : resvalue -> res -> res **)

let res_overwrite_value_if_empty rv r =
  if resvalue_compare r.res_value Resvalue_empty
  then res_with_value r rv
  else r

(** val res_label_in : res -> label_set -> bool **)

let res_label_in r labs =
  label_set_mem r.res_label labs

(** val convert_literal_to_prim : literal -> prim **)

let convert_literal_to_prim _foo_ = match _foo_ with
| Literal_null -> Value_null
| Literal_bool b -> Value_bool b
| Literal_number n -> Value_number n
| Literal_string s -> Value_string s

(** val type_of : value -> coq_type **)

let type_of _foo_ = match _foo_ with
| Value_undef -> Type_undef
| Value_null -> Type_null
| Value_bool b -> Type_bool
| Value_number n -> Type_number
| Value_string s -> Type_string
| Value_object o -> Type_object

let type_of_resvalue r = match r with
| Resvalue_empty   -> Type_resvalue_empty
| Resvalue_value _ -> Type_resvalue_value
| Resvalue_ref _   -> Type_resvalue_ref

let ref_of_resvalue r = match r with
| Resvalue_ref ref -> ref
| _ -> failwith "Pre-checked safe type conversion failed"

(** Default vales for data property attributes.
    @esid table-4
    @essec 6.1.7.1 Table 4 *)
let attributes_data_default =
  { attributes_data_value = Value_undef;
    attributes_data_writable = false;
    attributes_data_enumerable = false;
    attributes_data_configurable = false }

(** Default vales for accessor property attributes.
    @esid table-4
    @essec 6.1.7.1 Table 4 *)
let attributes_accessor_default =
  { attributes_accessor_get = Value_undef;
    attributes_accessor_set = Value_undef;
    attributes_accessor_enumerable = false;
    attributes_accessor_configurable = false }

(** Convert a data attribute into an accessor attribute.

    Implements the following spec text: "Convert the property \[...\] from a
    data property to an accessor property.  Preserve the existing values of the
    converted property's \[\[Configurable\]\] and \[\[Enumerable\]\] attributes
    and set the rest of the property's attributes to their default values."

    @essec 9.1.6.3-7.b.i *)
let attributes_accessor_of_attributes_data a =
  match a with
  | Attributes_data_of ad ->
    Attributes_accessor_of {
      attributes_accessor_get = attributes_accessor_default.attributes_accessor_get;
      attributes_accessor_set = attributes_accessor_default.attributes_accessor_set;
      attributes_accessor_enumerable = ad.attributes_data_enumerable;
      attributes_accessor_configurable = ad.attributes_data_configurable }
  | _ -> failwith "Pre-checked safe type conversion failed"

(** Convert an accessor attribute into a data attribute.

    Implements the following spec text: "Convert the property \[...\] from an
    accessor property to a data property.  Preserve the existing values of the
    converted property's \[\[Configurable\]\] and \[\[Enumerable\]\] attributes
    and set the rest of the property's attributes to their default values."

    @essec 9.1.6.3-7.c.i *)
let attributes_data_of_attributes_accessor a =
  match a with
  | Attributes_accessor_of aa ->
      Attributes_data_of {
        attributes_data_value = attributes_data_default.attributes_data_value;
        attributes_data_writable = attributes_data_default.attributes_data_writable;
        attributes_data_enumerable = aa.attributes_accessor_enumerable;
        attributes_data_configurable = aa.attributes_accessor_configurable }
  | _ -> failwith "Pre-checked safe type conversion failed"

(** Updates a given data attribute with values from the given descriptor *)
let attributes_data_update ad desc =
  { attributes_data_value =
      (unsome_default ad.attributes_data_value desc.descriptor_value);
    attributes_data_writable =
      (unsome_default ad.attributes_data_writable desc.descriptor_writable);
    attributes_data_enumerable =
      (unsome_default ad.attributes_data_enumerable desc.descriptor_enumerable);
    attributes_data_configurable =
      (unsome_default ad.attributes_data_configurable desc.descriptor_configurable) }

(** Updates a given accessor attribute with values from the given descriptor *)
let attributes_accessor_update aa desc =
  { attributes_accessor_get =
      (unsome_default aa.attributes_accessor_get desc.descriptor_get);
    attributes_accessor_set =
      (unsome_default aa.attributes_accessor_set desc.descriptor_set);
    attributes_accessor_enumerable =
      (unsome_default aa.attributes_accessor_enumerable desc.descriptor_enumerable);
    attributes_accessor_configurable =
      (unsome_default aa.attributes_accessor_configurable desc.descriptor_configurable) }

(** Updates a given attribute with values from the given descriptor. Additional
    attributes on the descriptor are ignored. *)
let attributes_update a desc =
  match a with
  | Attributes_data_of ad ->
      Attributes_data_of (attributes_data_update ad desc)
  | Attributes_accessor_of aa ->
      Attributes_accessor_of (attributes_accessor_update aa desc)

(** Create a data property from a descriptor, using default attribute values if
    the required attribute is absent. *)
let attributes_data_of_descriptor desc =
  attributes_data_update attributes_data_default desc

(** Create an accessor property from a descriptor, using default attribute
    values if the required attribute is absent. *)
let attributes_accessor_of_descriptor desc =
  attributes_accessor_update attributes_accessor_default desc

(** Converts a complete descriptor into attributes. Nonstandard operation for backwards compat only. Not to be used with
    generic descriptors.
    @deprecated For backwards compatibility only. *)
let attributes_of_descriptor desc =
  if (is_some desc.descriptor_get) || (is_some desc.descriptor_set) then
    Attributes_accessor_of (attributes_accessor_of_descriptor desc)
  else if is_some desc.descriptor_value then
    Attributes_data_of (attributes_data_of_descriptor desc)
  else
    failwith "attributes_of_descriptor type cast used with generic descriptor"

(** val descriptor_of_attributes : attributes -> descriptor **)

let descriptor_of_attributes _foo_ = match _foo_ with
| Attributes_data_of ad ->
  { descriptor_value = (Some ad.attributes_data_value);
    descriptor_writable = (Some ad.attributes_data_writable);
    descriptor_get = None;
    descriptor_set = None;
    descriptor_enumerable = (Some ad.attributes_data_enumerable);
    descriptor_configurable = (Some ad.attributes_data_configurable) }
| Attributes_accessor_of aa ->
  { descriptor_value = None;
    descriptor_writable = None;
    descriptor_get = (Some aa.attributes_accessor_get);
    descriptor_set = (Some aa.attributes_accessor_set);
    descriptor_enumerable = (Some aa.attributes_accessor_enumerable);
    descriptor_configurable = (Some aa.attributes_accessor_configurable) }

let full_descriptor_of_undef_descriptor desc =
  match desc with
  | Descriptor_undef -> Full_descriptor_undef
  | Descriptor desc -> Full_descriptor_some (attributes_of_descriptor desc)

let undef_descriptor_of_full_descriptor desc =
  match desc with
  | Full_descriptor_undef -> Descriptor_undef
  | Full_descriptor_some att -> Descriptor (descriptor_of_attributes att)

(** val attributes_configurable : attributes -> bool **)

let attributes_configurable _foo_ = match _foo_ with
| Attributes_data_of ad -> ad.attributes_data_configurable
| Attributes_accessor_of aa -> aa.attributes_accessor_configurable

(** val attributes_enumerable : attributes -> bool **)

let attributes_enumerable _foo_ = match _foo_ with
| Attributes_data_of ad -> ad.attributes_data_enumerable
| Attributes_accessor_of aa -> aa.attributes_accessor_enumerable

(** val state_with_object_heap :
    state -> (object_loc, coq_object) Heap.heap -> state **)

(* STATEFUL *)
let state_with_object_heap s new_object_heap =
  { s with state_object_heap = new_object_heap } 

(** val state_map_object_heap :
    state -> ((object_loc, coq_object) Heap.heap -> (object_loc, coq_object)
    Heap.heap) -> state **)

(* STATEFUL *)
let state_map_object_heap s f =
  state_with_object_heap s (f s.state_object_heap)

(** val object_write : state -> object_loc -> coq_object -> state **)

(* STATEFUL *)
let object_write s l o =
  state_map_object_heap s (fun h -> HeapObj.write h l o)

(** val object_alloc : state -> coq_object -> object_loc * state **)

(* STATEFUL *)
let object_alloc s o =
  let { state_object_heap = cells; state_env_record_heap = bindings;
    state_fresh_locations = state_fresh_locations0; } = s
  in
  let n = state_fresh_locations0 in
  let alloc = state_fresh_locations0 + 1 in
  let l = Object_loc_normal n in
  (l,
  (object_write { state_object_heap = cells; state_env_record_heap =
    bindings; state_fresh_locations = alloc } l
    o))

(** val object_map_properties :
    coq_object -> (object_properties_type -> object_properties_type) ->
    coq_object **)

let object_map_properties o f =
  object_with_properties o (f o.object_properties_)

(** val object_new : value -> class_name -> coq_object **)

let object_new vproto sclass =
  object_create_default_record vproto sclass true Heap.empty

let proxy_object_new s =
  let loc, s = object_alloc s proxy_object_create_record in
  s, loc

(** @essec sec-ecmascript-standard-built-in-objects
    @esid 17-11

    Unless otherwise specified, the length property of a built-in function object has the attributes
    {v \{ \[\[Writable\]\]: false, \[\[Enumerable\]\]: false, \[\[Configurable\]\]: true \} v}.
*)
let length_property_attributes length = {
  attributes_data_value = Value_number length;
  attributes_data_writable = false;
  attributes_data_enumerable = false;
  attributes_data_configurable = true;
}

let builtin_function_new s prototype bi length isconstructor =
  let props = HeapStr.write Heap.empty "length" (Attributes_data_of (length_property_attributes length)) in
  let loc, s = object_alloc s (create_builtin_function_record prototype bi props isconstructor) in
  s, Value_object loc

(** val attributes_writable : attributes -> bool **)

let attributes_writable _foo_ = match _foo_ with
| Attributes_data_of ad -> ad.attributes_data_writable
| Attributes_accessor_of aa -> false

(** val attributes_data_intro_constant : value -> attributes_data **)

let attributes_data_intro_constant v =
  { attributes_data_value = v; attributes_data_writable = false;
    attributes_data_enumerable = false; attributes_data_configurable =
    false }

(** val attributes_data_intro_all_true : value -> attributes_data **)

let attributes_data_intro_all_true v =
  { attributes_data_value = v; attributes_data_writable = true;
    attributes_data_enumerable = true; attributes_data_configurable = true }

(** val descriptor_intro_data :
    value -> bool -> bool -> bool -> descriptor **)

let descriptor_intro_data v bw be bc =
  { descriptor_value = (Some v); descriptor_writable = (Some bw);
    descriptor_get = None; descriptor_set = None; descriptor_enumerable =
    (Some be); descriptor_configurable = (Some bc) }

(** val descriptor_intro_empty : descriptor **)

let descriptor_intro_empty =
  { descriptor_value = None; descriptor_writable = None; descriptor_get =
    None; descriptor_set = None; descriptor_enumerable = None;
    descriptor_configurable = None }

type ref_kind =
| Ref_kind_null
| Ref_kind_undef
| Ref_kind_primitive_base
| Ref_kind_object
| Ref_kind_env_record

(** val ref_kind_of : ref -> ref_kind **)

let ref_kind_of r =
  match r.ref_base with
  | Ref_base_type_value v ->
    (match v with
     | Value_undef -> Ref_kind_undef
     | Value_null -> Ref_kind_null
     | Value_bool b -> Ref_kind_primitive_base
     | Value_number n -> Ref_kind_primitive_base
     | Value_string s -> Ref_kind_primitive_base
     | Value_object o -> Ref_kind_object)
  | Ref_base_type_env_loc l -> Ref_kind_env_record

let value_of_ref_base_type r = match r with
| Ref_base_type_value v -> v
| _ -> failwith "Pre-checked safe type conversion failed"

let env_loc_of_ref_base_type r = match r with
| Ref_base_type_env_loc l -> l
| _ -> failwith "Pre-checked safe type conversion failed"

(** val ref_create_value : value -> prop_name -> bool -> ref **)

let ref_create_value v x strict =
  { ref_base = (Ref_base_type_value v);
    ref_name = x;
    ref_strict = strict;
    ref_this_value = None
  }

(** val ref_create_env_loc : env_loc -> prop_name -> bool -> ref **)

let ref_create_env_loc l x strict =
  { ref_base = (Ref_base_type_env_loc l);
    ref_name = x;
    ref_strict = strict;
    ref_this_value = None
  }

(** val mutability_of_bool : bool -> mutability **)

let mutability_of_bool _foo_ = match _foo_ with
| true -> Mutability_deletable
| false -> Mutability_nondeletable

(** val state_with_env_record_heap :
    state -> (env_loc, env_record) Heap.heap -> state **)

(* STATEFUL *)
let state_with_env_record_heap s new_env_heap =
  let { state_object_heap = object_heap; state_env_record_heap =
    old_env_heap; state_fresh_locations = fresh_locs; } = s
  in
  { state_object_heap = object_heap; state_env_record_heap = new_env_heap;
  state_fresh_locations = fresh_locs }

(** val state_map_env_record_heap :
    state -> ((env_loc, env_record) Heap.heap -> (env_loc, env_record)
    Heap.heap) -> state **)

(* STATEFUL *)
let state_map_env_record_heap s f =
  state_with_env_record_heap s (f s.state_env_record_heap)

(** val env_record_write : state -> env_loc -> env_record -> state **)

(* STATEFUL *)
let env_record_write s l e =
  state_map_env_record_heap s (fun h -> HeapInt.write h l e)

(** val env_record_alloc : state -> env_record -> int * state **)

(* STATEFUL *)
let env_record_alloc s e =
  let { state_object_heap = cells; state_env_record_heap = bindings;
    state_fresh_locations = state_fresh_locations0;  } = s
  in
  let l =  state_fresh_locations0 in
  let alloc = state_fresh_locations0 + 1 in
  let bindings' = HeapInt.write bindings l e in
  (l, { state_object_heap = cells; state_env_record_heap = bindings';
  state_fresh_locations = alloc })

(** val provide_this_true : provide_this_flag **)

let provide_this_true =
  true

(** val provide_this_false : provide_this_flag **)

let provide_this_false =
  false

(** val env_record_object_default : object_loc -> env_record **)

let env_record_object_default l =
  Env_record_object (l, provide_this_false)

(** val decl_env_record_empty : decl_env_record **)

let decl_env_record_empty =
  Heap.empty

(** val decl_env_record_write :
    decl_env_record -> prop_name -> mutability -> value -> decl_env_record **)

let decl_env_record_write ed x mu v =
  HeapStr.write ed x (mu, v)

(** val decl_env_record_rem :
    decl_env_record -> prop_name -> decl_env_record **)

let decl_env_record_rem ed x =
  HeapStr.rem ed x

(** val env_record_write_decl_env :
    state -> env_loc -> prop_name -> mutability -> value -> state **)

(* STATEFUL *)
let env_record_write_decl_env s l x mu v =
  match HeapInt.read s.state_env_record_heap l with
  | Env_record_decl ed ->
    let env' = decl_env_record_write ed x mu v in
    env_record_write s l (Env_record_decl env')
  | Env_record_object (o, p) -> s

(** val lexical_env_alloc :
    state -> int list -> env_record -> int list * state **)

(* STATEFUL *)
let lexical_env_alloc s lex e =
  let (l, s') = env_record_alloc s e in let lex' = l :: lex in (lex', s')

(** val lexical_env_alloc_decl : state -> int list -> int list * state **)

(* STATEFUL *)
let lexical_env_alloc_decl s lex =
  lexical_env_alloc s lex (Env_record_decl decl_env_record_empty)

(** val lexical_env_alloc_object :
    state -> int list -> object_loc -> provide_this_flag -> int list * state **)

(* STATEFUL *)
let lexical_env_alloc_object s lex l pt =
  lexical_env_alloc s lex (Env_record_object (l, pt))

(** val execution_ctx_intro_same :
    lexical_env -> value -> strictness_flag -> execution_ctx **)

let execution_ctx_intro_same x lthis strict =
  { execution_ctx_lexical_env = x; execution_ctx_variable_env = x;
    execution_ctx_this_binding = lthis; execution_ctx_strict = strict }

(** val execution_ctx_with_lex :
    execution_ctx -> lexical_env -> execution_ctx **)

let execution_ctx_with_lex c lex =
  let { execution_ctx_lexical_env = x1; execution_ctx_variable_env = x2;
    execution_ctx_this_binding = x3; execution_ctx_strict = x4 } = c
  in
  { execution_ctx_lexical_env = lex; execution_ctx_variable_env = x2;
  execution_ctx_this_binding = x3; execution_ctx_strict = x4 }

(** val execution_ctx_with_lex_same :
    execution_ctx -> lexical_env -> execution_ctx **)

let execution_ctx_with_lex_same c lex =
  let { execution_ctx_lexical_env = x1; execution_ctx_variable_env = x2;
    execution_ctx_this_binding = x3; execution_ctx_strict = x4 } = c
  in
  { execution_ctx_lexical_env = lex; execution_ctx_variable_env = lex;
  execution_ctx_this_binding = x3; execution_ctx_strict = x4 }

(** val lexical_env_initial : lexical_env **)

let lexical_env_initial =
  env_loc_global_env_record :: []

(** val execution_ctx_initial : strictness_flag -> execution_ctx **)

let execution_ctx_initial str =
  { execution_ctx_lexical_env = lexical_env_initial;
    execution_ctx_variable_env = lexical_env_initial;
    execution_ctx_this_binding = (Value_object (Object_loc_prealloc
    Prealloc_global)); execution_ctx_strict = str }

(** val element_funcdecl : element -> funcdecl list **)

let element_funcdecl _foo_ = match _foo_ with
| Element_stat s -> []
| Element_func_decl (name, args, bd) ->
  { funcdecl_name = name; funcdecl_parameters = args; funcdecl_body =
    bd } :: []

(** val prog_funcdecl : prog -> funcdecl list **)

let prog_funcdecl p =
  concat (LibList.map element_funcdecl (prog_elements p))

(** val stat_vardecl : stat -> string list **)

let rec stat_vardecl _foo_ = match _foo_ with
| Stat_expr e -> []
| Stat_label (s0, s) -> stat_vardecl s
| Stat_block ts -> concat (LibList.map stat_vardecl ts)
| Stat_var_decl nes -> LibList.map fst nes
| Stat_if (e, s1, s2o) ->
  append (stat_vardecl s1)
    (unsome_default [] (LibOption.map stat_vardecl s2o))
| Stat_do_while (l, s, e) -> stat_vardecl s
| Stat_while (l, e, s) -> stat_vardecl s
| Stat_with (e, s) -> stat_vardecl s
| Stat_throw e -> []
| Stat_return o -> []
| Stat_break l -> []
| Stat_continue l -> []
| Stat_try (s, sco, sfo) ->
  append (stat_vardecl s)
    (append
      (unsome_default []
        (LibOption.map (fun sc -> stat_vardecl (snd sc)) sco))
      (unsome_default [] (LibOption.map stat_vardecl sfo)))
| Stat_for (l, o, o0, o1, s) -> stat_vardecl s
| Stat_for_var (l, nes, o, o0, s) ->
  append (LibList.map fst nes) (stat_vardecl s)
| Stat_for_in (l, e, e0, s) -> stat_vardecl s
| Stat_for_in_var (l, str, o, e, s) -> str :: (stat_vardecl s)
| Stat_debugger -> []
| Stat_switch (l, e, sb) -> switchbody_vardecl sb

(** val switchbody_vardecl : switchbody -> string list **)

and switchbody_vardecl _foo_ = match _foo_ with
| Switchbody_nodefault scl -> concat (LibList.map switchclause_vardecl scl)
| Switchbody_withdefault (scl1, sl, scl2) ->
  append (concat (LibList.map switchclause_vardecl scl1))
    (append (concat (LibList.map stat_vardecl sl))
      (concat (LibList.map switchclause_vardecl scl2)))

(** val switchclause_vardecl : switchclause -> string list **)

and switchclause_vardecl _foo_ = match _foo_ with
| Switchclause_intro (e, sl) -> concat (LibList.map stat_vardecl sl)

(** val element_vardecl : element -> string list **)

let element_vardecl _foo_ = match _foo_ with
| Element_stat t -> stat_vardecl t
| Element_func_decl (name, args, bd) -> []

(** val prog_vardecl : prog -> string list **)

let prog_vardecl p =
  concat (LibList.map element_vardecl (prog_elements p))

type preftype =
| Preftype_number
| Preftype_string

(** val method_of_preftype : preftype -> string **)

let method_of_preftype _foo_ = match _foo_ with
| Preftype_number -> "valueOf"
| Preftype_string ->
  "toString"

(** val other_preftypes : preftype -> preftype **)

let other_preftypes _foo_ = match _foo_ with
| Preftype_number -> Preftype_string
| Preftype_string -> Preftype_number

(** val throw_true : strictness_flag **)

let throw_true =
  true

(** val throw_false : strictness_flag **)

let throw_false =
  false

(** val throw_irrelevant : strictness_flag **)

let throw_irrelevant =
  false

(** val add_one : number -> number **)

let add_one n =
  n +. JsNumber.one

(** val sub_one : number -> number **)

let sub_one n =
  n -. JsNumber.one

(** val is_syntactic_eval : expr -> bool **)

let is_syntactic_eval _foo_ = match _foo_ with
| Expr_this -> false
| Expr_identifier s -> string_eq s ("eval")
| Expr_literal l ->
  (match l with
   | Literal_null -> false
   | Literal_bool b -> false
   | Literal_number n -> false
   | Literal_string s ->
     string_eq s ("eval"))
| Expr_object l -> false
| Expr_array l -> false
| Expr_function (o, l, f) -> false
| Expr_access (e0, e1) -> false
| Expr_member (e0, s) -> false
| Expr_new (e0, l) -> false
| Expr_call (e0, l) -> false
| Expr_unary_op (u, e0) -> false
| Expr_binary_op (e0, b, e1) -> false
| Expr_conditional (e0, e1, e2) -> false
| Expr_assign (e0, o, e1) -> false

(** val elision_head_count : 'a1 option list -> int **)

let rec elision_head_count _foo_ = match _foo_ with
| [] -> 0
| o :: ol' ->
  (match o with
   | Some t -> 0
   | None -> 1 + (elision_head_count ol'))

(** val elision_head_remove : 'a1 option list -> 'a1 option list **)

let rec elision_head_remove ol = match ol with
| [] -> ol
| o :: ol' ->
  (match o with
   | Some t -> ol
   | None -> elision_head_remove ol')

(** val elision_tail_count : 'a1 option list -> int **)

let elision_tail_count ol =
  elision_head_count (rev ol)

(** val elision_tail_remove : 'a1 option list -> 'a1 option list **)

let elision_tail_remove ol =
  rev (elision_head_remove (rev ol))

(** val parse_pickable : string -> bool -> prog coq_Pickable_option **)

let parse_pickable = (fun s strict ->
  Translate_syntax.parse_js_syntax strict s
    (*Translate_syntax.parse_esprima strict s*)
    (* with
      (* | Translate_syntax.CoqSyntaxDoesNotSupport _ -> assert false (* Temporary *) *)
      | Parser.ParserFailure _
      | Parser.InvalidArgument ->
        prerr_string ("Warning:  Parser error on eval.  Input string:  \"" ^ str ^ "\"\n");
        None
    *)
  )

