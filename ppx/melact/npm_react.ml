open Ppxlib
open Ast_builder.Default

(** Whether Melact's function for a binding is a hook, which takes its call site's key first. *)
type keying = Keyed | Plain

(** How a binding's arguments reach Melact's function. *)
type passing =
  | As_given
  | Listed of int  (** This argument is a tuple longer than Melact's hooks take, passed as the array it is in JavaScript. *)


let source attributes =
  List.find_map
    (fun attribute ->
      match (attribute.attr_name.txt, attribute.attr_payload) with
      | ("mel.module" | "bs.module"), PStr [ { pstr_desc = Pstr_eval ({ pexp_desc = Pexp_constant (Pconst_string (name, _, _)); _ }, _); _ } ]
        ->
          Some name
      | _ -> None)
    attributes

let parameters type_ =
  let rec collect type_ =
    match type_.ptyp_desc with
    | Ptyp_arrow (label, argument, rest) -> (label, argument) :: collect rest
    | Ptyp_poly (_, inner) -> collect inner
    | _ -> []
  in
  collect type_

let target package name type_ =
  let react keying found = Some (Ldot (Lident "React", found), keying, As_given)
  and dom found = Some (Ldot (Lident "ReactDOM", found), Plain, As_given) in
  let with_deps base deps =
    match List.nth_opt (parameters type_) deps with
    | None -> react Keyed base
    | Some (_, { ptyp_desc = Ptyp_tuple items; _ }) when List.length items <= 7 ->
        react Keyed (base ^ string_of_int (List.length items))
    | Some (_, { ptyp_desc = Ptyp_tuple _; _ }) -> Some (Ldot (Lident "React", base ^ "1"), Keyed, Listed deps)
    | Some (_, { ptyp_desc = Ptyp_constr ({ txt = Lident "unit"; _ }, []); _ }) -> react Keyed (base ^ "0")
    | Some _ -> react Keyed (base ^ "1")
  in
  match (package, name) with
  | "react", ("useState" | "useReducer" | "useRef" | "useId" | "useSyncExternalStore") -> react Keyed name
  | "react", ("useContext" | "useTransition" | "startTransition" | "useDebugValue" | "createContext" | "memo"
             | "forwardRef" | "isValidElement" | "cloneElement" | "createRef") ->
      react Plain name
  | "react", ("useEffect" | "useLayoutEffect" | "useMemo" | "useCallback" | "useInsertionEffect") -> with_deps name 1
  | "react", "useImperativeHandle" -> with_deps name 2
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
            | Some (found, keying, passing) ->
                let loc = description.pval_loc and name = description.pval_name.txt in
                let given = parameters description.pval_type in
                let arguments = List.mapi (fun index (label, _) -> (label, Printf.sprintf "melact_argument_%d" index)) given in
                let call =
                  List.mapi
                    (fun index (label, argument) ->
                      match passing with
                      | Listed at when at = index -> (label, [%expr Melact_runtime.Hook.listed [%e evar ~loc argument]])
                      | Listed _ | As_given -> (label, evar ~loc argument))
                    arguments
                  |> pexp_apply ~loc
                       (match keying with
                       | Plain -> pexp_ident ~loc { loc; txt = found }
                       | Keyed ->
                           pexp_apply ~loc (pexp_ident ~loc { loc; txt = found })
                             [ (Nolabel, [%expr Melact_runtime.Hook.unchecked [%e evar ~loc ("melact_key_" ^ name)]]) ])
                in
                let wrapper =
                  List.fold_right
                    (fun (label, argument) body -> pexp_fun ~loc label None (pvar ~loc argument) body)
                    arguments
                    { call with pexp_attributes = [ attribute ~loc ~name:{ loc; txt = "melact.keyed" } ~payload:(PStr []) ] }
                in
                let defined =
                  (match keying with
                  | Plain -> []
                  | Keyed -> [ [%stri let[@warning "-32"] [%p pvar ~loc ("melact_key_" ^ name)] = Melact_runtime.Hook.key ()] ])
                  @ [ [%stri let[@warning "-32"] [%p pvar ~loc name] = [%e wrapper]] ]
                in
                let renamed =
                  match passing with
                  | As_given -> [ (Lident name, found) ]
                  | Listed _ -> []
                in
                let later, exported = go (renamed @ renames) rest in
                (defined @ later, renamed @ exported)
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
