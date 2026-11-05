open Ppxlib


let source attributes =
  List.find_map
    (fun attribute ->
      match (attribute.attr_name.txt, attribute.attr_payload) with
      | ("mel.module" | "bs.module"), PStr [ { pstr_desc = Pstr_eval ({ pexp_desc = Pexp_constant (Pconst_string (name, _, _)); _ }, _); _ } ]
        ->
          Some name
      | _ -> None)
    attributes

let arity type_ =
  let rec count type_ =
    match type_.ptyp_desc with
    | Ptyp_arrow (_, _, rest) -> 1 + count rest
    | Ptyp_poly (_, inner) -> count inner
    | _ -> 0
  in
  count type_

let target package name type_ =
  let react found = Some (Ldot (Lident "React", found)) and dom found = Some (Ldot (Lident "ReactDOM", found)) in
  let with_deps base = match arity type_ with 1 -> react base | _ -> react (base ^ "1") in
  match (package, name) with
  | "react", ("useState" | "useReducer" | "useRef" | "useContext" | "useId" | "useTransition" | "startTransition"
             | "useDebugValue" | "useSyncExternalStore" | "createContext" | "memo" | "forwardRef" | "isValidElement"
             | "cloneElement" | "createRef") ->
      react name
  | "react", ("useEffect" | "useLayoutEffect" | "useMemo" | "useCallback" | "useInsertionEffect") -> with_deps name
  | "react", "useImperativeHandle" when arity type_ >= 3 -> react "useImperativeHandle1"
  | "react-dom", ("createPortal" | "flushSync") -> dom name
  | _ -> None

let structure items =
  let rewrite renames =
    object
      inherit Ast_traverse.map as super

      method! expression expression =
        match expression.pexp_desc with
        | Pexp_ident { txt; loc } -> (
            match List.assoc_opt txt renames with
            | Some found -> { expression with pexp_desc = Pexp_ident { txt = found; loc } }
            | None -> super#expression expression)
        | _ -> super#expression expression
    end
  in
  let rec go renames items =
    match items with
    | [] -> ([], [])
    | item :: rest -> (
        match item.pstr_desc with
        | Pstr_primitive description -> (
            match
              Option.bind (source description.pval_attributes) (fun package ->
                  Option.bind (List.nth_opt description.pval_prim 0) (fun name ->
                      target package name description.pval_type))
            with
            | Some found ->
                let renamed = (Lident description.pval_name.txt, found) in
                let later, exported = go (renamed :: renames) rest in
                (later, renamed :: exported)
            | None ->
                let later, exported = go renames rest in
                ((rewrite renames)#structure_item item :: later, exported))
        | Pstr_module ({ pmb_name = { txt = Some name; _ }; pmb_expr = { pmod_desc = Pmod_structure inner; _ } as body; _ } as binding) ->
            let inner, found = go renames inner in
            let qualified = List.map (fun (local, target) -> (Ldot (Lident name, Longident.last_exn local), target)) found in
            let item = { item with pstr_desc = Pstr_module { binding with pmb_expr = { body with pmod_desc = Pmod_structure inner } } } in
            let later, exported = go (qualified @ renames) rest in
            (item :: later, exported)
        | _ -> (
            let item = (rewrite renames)#structure_item item in
            match item.pstr_desc with
            | Pstr_value (_, bindings) ->
                let shadowed = List.concat_map (fun binding -> Melhole_compiler.Free.bound binding.pvb_pat) bindings in
                let later, exported =
                  go (List.filter (fun (name, _) -> match name with Lident name -> not (List.mem name shadowed) | _ -> true) renames) rest
                in
                (item :: later, exported)
            | _ ->
                let later, exported = go renames rest in
                (item :: later, exported)))
  in
  fst (go [] items)
