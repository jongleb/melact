open Ppxlib
open Ast_builder.Default

(** Whether Melact's function for a binding is a hook, which takes its call site's key first. *)
type keying = Keyed | Plain

(** How a binding's arguments reach Melact's function. *)
type passing =
  | As_given
  | Listed of int  (** This argument is a tuple longer than Melact's hooks take, passed as the array it is in JavaScript. *)
  | Children_from of int  (** An element: the arguments from this one on are its children. *)
  | Children_spread of int  (** An element: this argument is the array of its children ([[@mel.variadic]]). *)
  | Key_at of int  (** An element from the JSX runtime: this argument is its key. *)


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

let target package name type_ attributes =
  let created passing =
    let rec result type_ =
      match type_.ptyp_desc with
      | Ptyp_arrow (_, _, rest) | Ptyp_poly (_, rest) -> result rest
      | Ptyp_constr ({ txt = Ldot (Lident "React", "element"); _ }, []) -> Some (Ldot (Lident "Melact_npm", "created"), Plain, passing)
      | _ -> None
    in
    result type_
  in
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
  | "react", "useSyncExternalStore" when List.length (parameters type_) >= 3 -> react Keyed "useSyncExternalStoreWithServer"
  | "react", ("useState" | "useReducer" | "useRef" | "useId" | "useSyncExternalStore") -> react Keyed name
  | "react", ("useContext" | "useTransition" | "useDeferredValue" | "startTransition" | "useDebugValue" | "createContext" | "memo"
             | "forwardRef" | "isValidElement" | "cloneElement" | "createRef") ->
      react Plain name
  | "react", ("useEffect" | "useLayoutEffect" | "useMemo" | "useCallback" | "useInsertionEffect") -> with_deps name 1
  | "react", "useImperativeHandle" -> with_deps name 2
  | "react-dom", ("createPortal" | "flushSync") -> dom name
  | "react", "createElement" -> (
      match
        List.exists (fun attribute -> String.equal attribute.attr_name.txt "mel.variadic" || String.equal attribute.attr_name.txt "bs.splice") attributes
      with
      | true -> created (Children_spread 2)
      | false -> created (Children_from 2))
  | ("react/jsx-runtime" | "react/jsx-dev-runtime"), ("jsx" | "jsxs" | "jsxDEV") -> (
      match List.length (parameters type_) with 2 -> created (Children_from 2) | _ -> created (Key_at 2))
  | ("react" | "react/jsx-runtime" | "react/jsx-dev-runtime"), "Fragment" -> (
      let rec component type_ =
        match type_.ptyp_desc with
        | Ptyp_var _ | Ptyp_constr ({ txt = Ldot (Lident "React", "element"); _ }, [])
        | Ptyp_constr ({ txt = Ldot (Lident "React", "component"); _ }, [ _ ]) ->
            Some (Ldot (Lident "Melact_npm", "fragment"), Plain, As_given)
        | Ptyp_arrow (_, _, rest) | Ptyp_poly (_, rest) -> component rest
        | _ -> None
      in
      component type_)
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
                      target package name description.pval_type description.pval_attributes))
            with
            | Some (found, keying, passing) ->
                let loc = description.pval_loc and name = description.pval_name.txt in
                let given = parameters description.pval_type in
                let arguments = List.mapi (fun index (label, _) -> (label, Printf.sprintf "_melact_argument_%d" index)) given in
                let callee =
                  match keying with
                  | Plain -> pexp_ident ~loc { loc; txt = found }
                  | Keyed ->
                      pexp_apply ~loc (pexp_ident ~loc { loc; txt = found })
                        [ (Nolabel, [%expr Melact_runtime.Hook.unchecked [%e evar ~loc ("melact_key_" ^ name)]]) ]
                in
                let argument index =
                  Option.fold ~none:[%expr Js.Obj.empty ()] ~some:(fun (_, argument) -> evar ~loc argument) (List.nth_opt arguments index)
                in
                let element children = [%expr [%e callee] [%e argument 0] [%e argument 1] [%e children]] in
                let call =
                  match (passing, arguments) with
                  | (As_given | Listed _), [] -> callee
                  | (As_given | Listed _), _ :: _ ->
                      pexp_apply ~loc callee
                        (List.mapi
                           (fun index (label, argument) ->
                             match passing with
                             | Listed at when at = index -> (label, [%expr Melact_runtime.Hook.listed [%e evar ~loc argument]])
                             | Listed _ | As_given | Children_from _ | Children_spread _ | Key_at _ -> (label, evar ~loc argument))
                           arguments)
                  | Children_from from, _ ->
                      element (pexp_array ~loc (List.filteri (fun index _ -> index >= from) arguments |> List.map (fun (_, argument) -> evar ~loc argument)))
                  | Children_spread at, _ -> element (argument at)
                  | Key_at at, _ ->
                      [%expr
                        Melact_npm.keyed
                          [%e element [%expr [||]]]
                          [%e
                            Option.fold ~none:[%expr None]
                              ~some:(fun (label, argument) ->
                                match label with
                                | Optional _ -> evar ~loc argument
                                | Labelled _ | Nolabel -> [%expr Some [%e evar ~loc argument]])
                              (List.nth_opt arguments at)]]
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
                  | Listed _ | Children_from _ | Children_spread _ | Key_at _ -> []
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
