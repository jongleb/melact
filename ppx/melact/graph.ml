open Ppxlib
open Melhole_compiler

type rendering = Pure | Impure

exception Reads_the_world

let rendering body =
  let hook callee =
    match callee.pexp_desc with
    | Pexp_ident { txt; _ } -> (
        let name = Longident.last_exn txt in
        match String.length name >= 3 && String.equal (String.sub name 0 3) "use" with
        | true when String.length name = 3 || Char.uppercase_ascii name.[3] = name.[3] ->
            let rec trimmed length =
              match length > 0 && name.[length - 1] >= '0' && name.[length - 1] <= '9' with
              | true -> trimmed (length - 1)
              | false -> length
            in
            Some (String.sub name 0 (trimmed (String.length name)))
        | true | false -> None)
    | _ -> None
  in
  let rec now expression =
    let each = List.iter now in
    let cases branches =
      List.iter
        (fun case ->
          Option.iter now case.pc_guard;
          now case.pc_rhs)
        branches
    in
    let called_later value = match value.pexp_desc with Pexp_function _ -> () | _ -> now value in
    match expression.pexp_desc with
    | Pexp_ident { txt = Ldot (Ldot (Lident "Js", ("Date" | "Math")), _) | Ldot (Lident ("Random" | "Sys" | "Unix"), _); _ } ->
        raise Reads_the_world
    | Pexp_ident _ | Pexp_constant _ | Pexp_unreachable -> ()
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident ("!" | ":=" | "incr" | "decr"); _ }; _ }, _) ->
        raise Reads_the_world
    | Pexp_apply (_, arguments) when Option.is_some (Element.without_jsx expression.pexp_attributes) ->
        List.iter
          (fun (label, value) ->
            match (label, Element.list_items value) with
            | Labelled "children", Some items -> each items
            | _ -> called_later value)
          arguments
    | Pexp_apply (callee, arguments) -> (
        let values = List.map snd arguments in
        match (hook callee, arguments) with
        | Some ("useEffect" | "useLayoutEffect" | "useInsertionEffect" | "useCallback" | "useImperativeHandle"), _ ->
            List.iter called_later values
        | Some ("useReducer" | "useReducerWithMapState"), _ -> (
            match values with
            | reducer :: rest ->
                called_later reducer;
                each rest
            | [] -> ())
        | Some ("useState" | "useMemo" | "useContext" | "useRef" | "useId" | "useDebugValue"), _ -> each values
        | Some _, _ -> raise Reads_the_world
        | None, [ (Nolabel, { pexp_desc = Pexp_construct ({ txt = Lident "()"; _ }, None); _ }) ] -> raise Reads_the_world
        | None, _ ->
            now callee;
            each values)
    | Pexp_field (_, { txt = Lident ("contents" | "current") | Ldot (_, ("contents" | "current")); _ }) ->
        raise Reads_the_world
    | Pexp_field (target, _) -> now target
    | Pexp_let (_, bindings, rest) ->
        List.iter (fun binding -> now binding.pvb_expr) bindings;
        now rest
    | Pexp_function (params, _, function_body) -> (
        List.iter
          (fun param ->
            match param.pparam_desc with Pparam_val (_, default, _) -> Option.iter now default | Pparam_newtype _ -> ())
          params;
        match function_body with Pfunction_body inner -> now inner | Pfunction_cases (branches, _, _) -> cases branches)
    | Pexp_match (target, branches) | Pexp_try (target, branches) ->
        now target;
        cases branches
    | Pexp_tuple items | Pexp_array items -> each items
    | Pexp_construct (_, argument) | Pexp_variant (_, argument) -> Option.iter now argument
    | Pexp_record (fields, base) ->
        List.iter (fun (_, value) -> now value) fields;
        Option.iter now base
    | Pexp_ifthenelse (test, yes, no) ->
        now test;
        now yes;
        Option.iter now no
    | Pexp_sequence (first, second) ->
        now first;
        now second
    | Pexp_constraint (inner, _)
    | Pexp_coerce (inner, _, _)
    | Pexp_lazy inner
    | Pexp_assert inner
    | Pexp_newtype (_, inner)
    | Pexp_poly (inner, _)
    | Pexp_open (_, inner) ->
        now inner
    | Pexp_setfield _ | Pexp_while _ | Pexp_for _ | Pexp_send _ | Pexp_new _ | Pexp_setinstvar _ | Pexp_override _
    | Pexp_letmodule _ | Pexp_letexception _ | Pexp_object _ | Pexp_pack _ | Pexp_letop _ | Pexp_extension _ ->
        raise Reads_the_world
  in
  match now body with () -> Pure | exception Reads_the_world -> Impure
