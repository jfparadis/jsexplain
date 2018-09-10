let get_value_ref state r =
    match JsInterpreter.ref_get_value
        state (JsCommon.execution_ctx_initial false)
        (JsSyntax.Coq_resvalue_ref r) with
    | JsInterpreterMonads.Coq_result_some r ->
      (match r with
      | JsSyntax.Coq_specret_val (_, v) -> Some v
      | _ -> None)
    | _ -> None

let get_object_value state vobj name =
  get_value_ref state {
    JsSyntax.ref_base = JsSyntax.Coq_ref_base_type_value vobj;
    JsSyntax.ref_name = name;
    JsSyntax.ref_strict = false;
    JsSyntax.ref_this_value = None
  }

let get_global_value state name =
    let r =
      JsCommon.ref_create_env_loc
        JsSyntax.env_loc_global_env_record
        name true in
    get_value_ref state r
