open Ppxlib
open Melhole_compiler
open Ast_builder.Default

let keyed_hooks =
  [
    "useState"; "useReducer"; "useReducerWithMapState"; "useRef"; "useId"; "useEffect";
    "useLayoutEffect"; "useMemo"; "useCallback"; "useInsertionEffect"; "useSyncExternalStore"; "useSyncExternalStoreWithServer";
    "useDeferredValue";
  ]
  @ List.concat_map
      (fun base -> List.init 8 (fun arity -> base ^ string_of_int arity))
      [
        "useEffect"; "useLayoutEffect"; "useInsertionEffect"; "useMemo"; "useCallback";
        "useImperativeHandle";
      ]

let experimental_hooks = [ "useTransitionAsync"; "useOptimistic"; "useActionState" ]
let inline_fact = "melhole.inline"
let inline_version = 1
let own_module = "Melhole_own_module__"

let without_component attributes =
  match
    List.partition
      (fun attribute -> String.equal attribute.attr_name.txt "react.component")
      attributes
  with
  | [], _ -> None
  | _ :: _, rest -> Some rest

let unwrap ~loc element =
  [%expr
    React.to_child [%e element]]

let react_text expression =
  let text name =
    match name with
    | "string" -> Some Element.String_text
    | "int" -> Some Int_text
    | "float" -> Some Float_text
    | _ -> None
  in
  match expression.pexp_desc with
  | Pexp_ident { txt = Ldot (Lident "React", "null"); _ } -> Some Element.Nothing
  | Pexp_apply
      ({ pexp_desc = Pexp_ident { txt = Ldot (Lident "React", name); _ }; _ }, [ (Nolabel, value) ])
  | Pexp_apply
      ( { pexp_desc = Pexp_ident { txt = Lident "|."; _ }; _ },
        [
          (Nolabel, value);
          (Nolabel, { pexp_desc = Pexp_ident { txt = Ldot (Lident "React", name); _ }; _ });
        ] ) ->
      Option.map (fun kind -> Element.Text (kind, value)) (text name)
  | _ -> None

let component ~loc ~name ~props_constructor expression =
  let rec gather forwarding expression =
    match expression.pexp_desc with
    | Pexp_apply
        ( {
            pexp_desc =
              Pexp_ident
                { txt = Ldot (Lident "React", ("memo" | "memoCustomCompareProps")); _ };
            _;
          },
          (Nolabel, inner) :: _ ) ->
        gather forwarding inner
    | Pexp_apply
        ( { pexp_desc = Pexp_ident { txt = Ldot (Lident "React", "forwardRef"); _ }; _ },
          [ (Nolabel, inner) ] ) ->
        gather `Forwards_ref inner
    | Pexp_function (params, None, Pfunction_body body) ->
        let more, body, forwarding = gather forwarding body in
        (params @ more, body, forwarding)
    | Pexp_function (params, Some (Pconstraint result), Pfunction_body body) ->
        (params, pexp_constraint ~loc:body.pexp_loc body result, forwarding)
    | Pexp_function (_, _, _) ->
        Location.raise_errorf ~loc:expression.pexp_loc
          "melact: a [@react.component] takes labelled arguments and returns an element"
    | _ -> ([], expression, forwarding)
  in
  let params, body =
    match gather `Plain expression with
    | params, body, `Plain -> (params, body)
    | params, body, `Forwards_ref -> (
        match List.rev params with
        | { pparam_desc = Pparam_val (Nolabel, None, reference); _ } :: labelled ->
            ( List.rev labelled
              @ [
                  {
                    pparam_loc = loc;
                    pparam_desc =
                      Pparam_val (Optional "ref", None, [%pat? __melhole_forwarded_ref]);
                  };
                ],
              [%expr
                let [%p reference] = ReactDOM.Ref.forwarded __melhole_forwarded_ref in
                [%e body]] )
        | _ ->
            Location.raise_errorf ~loc
              "melact: React.forwardRef takes a function whose last argument is the ref")
  in
  let rec trailing params =
    match params with
    | [] -> `Missing
    | [ { pparam_desc = Pparam_val (Nolabel, None, _); _ } ] -> `Present
    | { pparam_desc = Pparam_val (Nolabel, _, _); pparam_loc; _ } :: _ ->
        Location.raise_errorf ~loc:pparam_loc
          "melact: only the last argument of a [@react.component] may be unlabelled"
    | _ :: rest -> trailing rest
  in
  let names =
    List.mapi
      (fun index _ -> Printf.sprintf "__melhole_prop_%d" index)
      (List.filter
         (fun param ->
           match param.pparam_desc with
           | Pparam_val ((Labelled _ | Optional _), _, _) -> true
           | Pparam_val (Nolabel, _, _) | Pparam_newtype _ -> false)
         params)
  in
  let next = ref names in
  let defaulted = ref [] in
  let aliased =
    List.map
      (fun param ->
        match (param.pparam_desc, !next) with
        | Pparam_val (((Labelled _ | Optional _) as label), default, pattern), name :: rest
          -> (
            next := rest;
            let named =
              match pattern.ppat_desc with
              | Ppat_constraint (inner, type_) ->
                  { pattern with ppat_desc = Ppat_constraint (ppat_alias ~loc inner { loc; txt = name }, type_) }
              | _ -> ppat_alias ~loc pattern { loc; txt = name }
            in
            match (label, default) with
            | Optional _, Some default ->
                let given = name ^ "_given" in
                defaulted := (named, given, default) :: !defaulted;
                { param with pparam_desc = Pparam_val (label, None, pvar ~loc given) }
            | (Labelled _ | Optional _ | Nolabel), _ -> { param with pparam_desc = Pparam_val (label, default, named) })
        | Pparam_val ((Labelled _ | Optional _), _, _), []
        | Pparam_val (Nolabel, _, _), _
        | Pparam_newtype _, _ ->
            param)
      params
  in
  let complete =
    match trailing params with
    | `Present -> aliased
    | `Missing ->
        aliased @ [ { pparam_loc = loc; pparam_desc = Pparam_val (Nolabel, None, [%pat? ()]) } ]
  in
  let rendering = Graph.rendering expression in
  let definition =
    lazy
      (Hoist.hoist ~loc "component"
         (match rendering with
         | Graph.Pure -> [%expr Melact_runtime.Component.pure ~name:[%e estring ~loc name]]
         | Graph.Impure -> [%expr Melact_runtime.Component.make ~name:[%e estring ~loc name]]))
  in
  let read_fields =
    List.concat_map
      (fun param ->
        match param.pparam_desc with
        | Pparam_val ((Labelled _ | Optional _), None, { ppat_desc = Ppat_var { txt; _ } | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _); _ })
          ->
            [ (txt, Free.use txt body) ]
        | Pparam_val _ | Pparam_newtype _ -> [])
      params
  in
  let field_inputs =
    let labelled =
      List.filter_map
        (fun param ->
          match param.pparam_desc with
          | Pparam_val ((Labelled _ | Optional _), default, pattern) -> Some (default, pattern)
          | Pparam_val (Nolabel, _, _) | Pparam_newtype _ -> None)
        params
    in
    List.map2
      (fun name (default, pattern) ->
        let variable =
          match pattern.ppat_desc with
          | Ppat_var { txt; _ } | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _) -> Some txt
          | _ -> None
        in
        match (default, Option.bind variable (fun variable -> List.assoc_opt variable read_fields)) with
        | None, Some (Free.Fields fields) ->
            List.rev_map (fun field -> [%expr Melhole.View.Input [%e pexp_field ~loc (evar ~loc name) field]]) fields
        | (None | Some _), (Some (Free.Fields _ | Whole) | None) -> [ [%expr Melhole.View.Input [%e evar ~loc name]] ])
      names
      (List.filteri (fun index _ -> index < List.length names) labelled)
  in
  let inputs = pexp_array ~loc (List.concat field_inputs) in
  let props =
    let rec bits offset patterns counts =
      match (patterns, counts) with
      | pattern :: patterns, count :: counts ->
          let mask = match offset + count <= 30 with true -> ((1 lsl count) - 1) lsl offset | false -> Graph.full - 1 in
          List.map (fun name -> (name, mask)) (Free.bound pattern) @ bits (offset + count) patterns counts
      | [], _ | _, [] -> []
    in
    bits 0
      (List.filter_map
         (fun param ->
           match param.pparam_desc with
           | Pparam_val ((Labelled _ | Optional _), _, pattern) -> Some pattern
           | Pparam_val (Nolabel, _, _) | Pparam_newtype _ -> None)
         params)
      (List.map List.length field_inputs)
  in
  let stateful expression =
    let finder =
      object
        inherit [[ `Pure | `Stateful ]] Ast_traverse.fold as super

        method! expression expression found =
          match (found, expression.pexp_desc) with
          | `Stateful, _ -> `Stateful
          | `Pure, Pexp_ident { txt; _ } -> (
              let name = Longident.last_exn txt in
              match String.length name >= 3 && String.equal (String.sub name 0 3) "use" with
              | true when String.length name = 3 || Char.uppercase_ascii name.[3] = name.[3] -> `Stateful
              | true | false -> `Pure)
          | `Pure, _ -> super#expression expression found
      end
    in
    finder#expression expression `Pure
  in
  let kind = stateful body in
  let body =
    match (kind, !Element.output) with
    | `Pure, _ | `Stateful, Element.Server -> body
    | `Stateful, (Element.Client_only | Element.Hydratable) -> (
        let sites = ref 0 in
        let untagged =
          object
            inherit Ast_traverse.map as super

            method! expression expression =
              let expression = super#expression expression in
              match expression.pexp_desc with
              | Pexp_apply (({ pexp_desc = Pexp_ident { txt = Lident _; loc }; _ } as callee), arguments)
                when Option.is_some (Element.without_jsx expression.pexp_attributes) ->
                  {
                    expression with
                    pexp_desc = Pexp_apply ({ callee with pexp_desc = Pexp_ident { txt = Ldot (Lident "Tag", "tag"); loc } }, arguments);
                  }
              | _ -> expression
          end
        in
        let bound_here =
          let collector =
            object
              inherit [string list] Ast_traverse.fold as super

              method! pattern pattern found =
                super#pattern pattern
                  (match pattern.ppat_desc with
                  | Ppat_var { txt; _ } | Ppat_alias (_, { txt; _ }) -> txt :: found
                  | _ -> found)
            end
          in
          List.fold_left
            (fun found param ->
              match param.pparam_desc with Pparam_val (_, _, pattern) -> collector#pattern pattern found | Pparam_newtype _ -> found)
            (collector#expression body []) params
        in
        let cache value =
          match (stateful value, Free.captured (untagged#expression value)) with
          | `Stateful, _ | `Pure, Volatile -> value
          | `Pure, Reads names -> (
              let captures =
                List.map (evar ~loc)
                  (List.filter (fun name -> List.mem name bound_here) names)
              in
              let at = !sites and count = List.length captures in
              sites := at + count + 1;
              let lookup =
                match captures with
                | [] -> [%expr Melact_runtime.Memo.lookup0 __melact_memo [%e eint ~loc at]]
                | [ a ] -> [%expr Melact_runtime.Memo.lookup1 __melact_memo [%e eint ~loc at] [%e a]]
                | [ a; b ] -> [%expr Melact_runtime.Memo.lookup2 __melact_memo [%e eint ~loc at] [%e a] [%e b]]
                | [ a; b; c ] ->
                    [%expr Melact_runtime.Memo.lookup3 __melact_memo [%e eint ~loc at] [%e a] [%e b] [%e c]]
                | [ a; b; c; d ] ->
                    [%expr Melact_runtime.Memo.lookup4 __melact_memo [%e eint ~loc at] [%e a] [%e b] [%e c] [%e d]]
                | more ->
                    [%expr
                      Melact_runtime.Memo.lookup __melact_memo [%e eint ~loc at]
                        [%e pexp_array ~loc (List.map (fun capture -> [%expr Melhole.View.Input [%e capture]]) more)]]
              in
              [%expr
                let __melact_found = [%e lookup] in
                match Melact_runtime.Memo.kept __melact_found with
                | Some __melact_kept -> __melact_kept
                | None -> Melact_runtime.Memo.store __melact_memo [%e eint ~loc (at + count)] __melact_found [%e value]])
        in
        let rec worth value =
          match value.pexp_desc with
          | Pexp_function _ | Pexp_record _ | Pexp_array _ | Pexp_tuple _ | Pexp_construct (_, Some _)
          | Pexp_variant (_, Some _) ->
              `Worth
          | Pexp_apply _ when Option.is_some (Element.without_jsx value.pexp_attributes) -> `Worth
          | Pexp_apply
              ( {
                  pexp_desc =
                    Pexp_ident
                      { txt = Ldot (Ldot (Lident "ReactDOM", "Style"), ("make" | "combine" | "unsafeAddProp")); _ };
                  _;
                },
                _ ) ->
              `Worth
          | Pexp_constraint (inner, _) -> worth inner
          | _ -> `Not
        in
        let walker =
          object (walker)
            inherit Ast_traverse.map as super

            method! expression expression =
              let passed value =
                let inner = match value.pexp_desc with Pexp_function _ -> value | _ -> walker#expression value in
                match worth value with `Worth -> cache inner | `Not -> inner
              in
              match expression.pexp_desc with
              | Pexp_function _ -> expression
              | Pexp_let (Nonrecursive, bindings, rest) ->
                  let bound binding =
                    let named =
                      match binding.pvb_pat.ppat_desc with
                      | Ppat_var { txt; _ } | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _) -> Some txt
                      | _ -> None
                    in
                    let value = binding.pvb_expr in
                    let kept =
                      Option.bind named (fun name ->
                          match value.pexp_desc with
                          | Pexp_function _ -> Some value
                          | Pexp_ident _ | Pexp_constant _ | Pexp_construct (_, None) | Pexp_variant (_, None) -> None
                          | _ -> (
                              match Frozen.uses name rest with
                              | Frozen.Read_only -> Some (walker#expression value)
                              | Frozen.Possibly_changed -> None))
                    in
                    Option.fold
                      ~none:{ binding with pvb_expr = (match value.pexp_desc with Pexp_function _ -> value | _ -> walker#expression value) }
                      ~some:(fun inner ->
                        let cached = cache inner in
                        {
                          binding with
                          pvb_expr =
                            (match cached == inner with
                            | true -> cached
                            | false ->
                                {
                                  cached with
                                  pexp_attributes =
                                    attribute ~loc ~name:{ txt = "melhole.cached"; loc }
                                      ~payload:(PStr [ pstr_eval ~loc inner [] ])
                                    :: cached.pexp_attributes;
                                });
                        })
                      kept
                  in
                  { expression with pexp_desc = Pexp_let (Nonrecursive, List.map bound bindings, walker#expression rest) }
              | Pexp_apply (({ pexp_desc = Pexp_ident { txt = Ldot _; _ }; _ } as callee), arguments)
                when Option.is_some (Element.without_jsx expression.pexp_attributes) ->
                  {
                    expression with
                    pexp_desc =
                      Pexp_apply
                        ( callee,
                          List.map
                            (fun (label, value) ->
                              match (label, Element.list_items value) with
                              | (Labelled "key" | Nolabel), _ -> (label, value)
                              | Labelled "children", Some items ->
                                  (label, { value with pexp_desc = (elist ~loc (List.map passed items)).pexp_desc })
                              | (Labelled _ | Optional _), _ -> (label, passed value))
                            arguments );
                  }
              | _ -> super#expression expression
          end
        in
        let remembered walked count =
          [%expr
            let __melact_memo =
              Melact_runtime.Memo.cells
                [%e Hoist.hoist ~loc "hook" [%expr (Melact_runtime.Hook.key () : Melact_runtime.Memo.t Melact_runtime.Hook.key)]]
                [%e eint ~loc count]
            in
            [%e walked]]
        in
        match
          match rendering with
          | Graph.Pure -> Graph.plan ~inputs:(List.length (List.concat field_inputs)) ~props body
          | Graph.Impure -> None
        with
        | Some plan ->
            let held pattern mask ~source value kept rest =
              let at = !sites in
              sites := at + 1;
              let found =
                [%expr
                  let __melact_found =
                    Melact_runtime.Memo.graph __melact_memo [%e eint ~loc at] __melact_changed [%e eint ~loc mask]
                  in
                  match Melact_runtime.Memo.kept __melact_found with
                  | Some __melact_kept -> [%e kept]
                  | None -> Melact_runtime.Memo.store __melact_memo [%e eint ~loc at] __melact_found [%e value]]
              in
              [%expr
                let [%p pattern] =
                  [%e
                    {
                      found with
                      pexp_attributes =
                        attribute ~loc ~name:{ txt = "melhole.cached"; loc } ~payload:(PStr [ pstr_eval ~loc source [] ])
                        :: found.pexp_attributes;
                    }]
                in
                [%e rest]]
            in
            let graphed =
              List.fold_right
                (fun step rest ->
                  match step with
                  | Graph.Statement value -> [%expr [%e walker#expression value]; [%e rest]]
                  | Graph.Called (pattern, value) -> [%expr let [%p pattern] = [%e value] in [%e rest]]
                  | Graph.Context { pattern; context; bit } ->
                      held pattern (bit lor Graph.full) ~source:[%expr React.useContext [%e context]]
                        [%expr
                          Melact_runtime.Instance.consume_source (Melact_runtime.Instance.current ()) [%e eint ~loc bit]
                            (match [%e context] with React.Context.Context __melact_context -> __melact_context)]
                        [%expr __melact_kept] rest
                  | Graph.Memo { pattern; hook; mask } ->
                      held pattern mask ~source:hook [%expr ([%e hook] [@alert "-hook"])]
                        [%expr Melact_runtime.Instance.skip_hook (); __melact_kept] rest
                  | Graph.Effect { hook; mask } ->
                      [%expr
                        (match __melact_changed land [%e eint ~loc mask] with
                        | 0 -> Melact_runtime.Instance.skip_hook ()
                        | _ -> (([%e hook] [@alert "-hook"]) : unit));
                        [%e rest]]
                  | Graph.Derived { pattern; value; mask } ->
                      held pattern mask ~source:value (walker#expression value) [%expr __melact_kept] rest)
                plan.steps
                [%expr
                  match __melact_changed land [%e eint ~loc plan.reads] with
                  | 0 -> React.of_child Melact_runtime.Instance.unchanged
                  | _ -> [%e walker#expression plan.result]]
            in
            remembered [%expr let __melact_changed = Melact_runtime.Instance.changed () in [%e graphed]] (max 1 !sites)
        | None -> (
            let walked = walker#expression body in
            match !sites with 0 -> body | count -> remembered walked count))
  in
  let checked =
    let watched expression =
      {
        expression with
        pexp_attributes =
          attribute ~loc:expression.pexp_loc ~name:{ txt = "alert"; loc = expression.pexp_loc }
            ~payload:(PStr [ pstr_eval ~loc (estring ~loc "+hook") [] ])
          :: expression.pexp_attributes;
      }
    in
    let marker =
      object
        inherit Ast_traverse.map as super

        method! expression expression =
          let expression = super#expression expression in
          match expression.pexp_desc with
          | Pexp_ifthenelse (test, yes, no) ->
              { expression with pexp_desc = Pexp_ifthenelse (test, watched yes, Option.map watched no) }
          | Pexp_match (target, cases) ->
              {
                expression with
                pexp_desc =
                  Pexp_match (target, List.map (fun case -> { case with pc_rhs = watched case.pc_rhs }) cases);
              }
          | Pexp_function _ -> watched expression
          | Pexp_while (test, body) -> { expression with pexp_desc = Pexp_while (test, watched body) }
          | Pexp_for (pattern, low, high, direction, body) ->
              { expression with pexp_desc = Pexp_for (pattern, low, high, direction, watched body) }
          | _ -> expression
      end
    in
    marker#expression body
  in
  let keyed =
    match List.rev complete with
    | last :: labelled ->
        List.rev labelled
        @ [
            {
              pparam_loc = loc;
              pparam_desc =
                Pparam_val
                  ( Optional "key",
                    None,
                    match !Element.output with
                    | Element.Server -> [%pat? (_ : string option)]
                    | Element.Client_only | Element.Hydratable -> [%pat? __melhole_key] );
            };
            last;
          ]
    | [] -> complete
  in
  let element =
    match (kind, !Element.output) with
    | `Stateful, Element.Server ->
        [%expr React.of_child (Melact_server.Component.render (fun () -> [%e unwrap ~loc checked]))]
    | `Pure, Element.Server ->
        [%expr
          React.of_child
            (Melhole_server.element (fun __melhole_writer ->
                 Melhole_server.write __melhole_writer [%e unwrap ~loc body]))]
    | `Stateful, (Element.Client_only | Element.Hydratable) ->
        [%expr
          React.of_child
            (Melact_runtime.Instance.component [%e Lazy.force definition] [%e inputs] (fun () -> [%e unwrap ~loc checked]))]
    | `Pure, (Element.Client_only | Element.Hydratable) ->
        [%expr React.of_child (Melhole.View.pure [%e Lazy.force definition] [%e inputs] (fun () -> [%e unwrap ~loc body]))]
  in
  let with_defaults body =
    List.fold_left
      (fun body (named, given, default) ->
        match !Element.output with
        | Element.Server ->
            [%expr
              let [%p named] = match [%e evar ~loc given] with Some __melhole_value -> __melhole_value | None -> [%e default] in
              [%e body]]
        | Element.Client_only | Element.Hydratable ->
            [%expr
              let [%p named] =
                match [%e evar ~loc given] with
                | Some __melhole_value when not (Js.Undefined.testAny __melhole_value) -> __melhole_value
                | Some _ | None -> [%e default]
              in
              [%e body]])
      body !defaulted
  in
  let constructed =
    pexp_construct ~loc { loc; txt = Lident props_constructor }
      (Some
         (match !Element.output with
         | Element.Server -> [%expr __melhole_element]
         | Element.Client_only | Element.Hydratable ->
             [%expr
               match __melhole_key with
               | None -> __melhole_element
               | Some key -> React.of_child (Melhole.View.with_key key (React.to_child __melhole_element))]))
  in
  pexp_function ~loc keyed None
    (Pfunction_body
       (with_defaults [%expr
         let __melhole_element = [%e element] in
         [%e constructed]]))

let props_name name = match name with "make" -> "makeProps" | other -> other ^ "Props"
let props_type name = name ^ "_props"

(** Modules whose [use…] functions are React's hooks, from [-hook-modules]. *)
let hook_modules = ref []

(** Whether [open React] is in force, so that a bare [useState] is React's. *)
type opened = Opened | Closed

let rec with_unit typ =
  match typ.ptyp_desc with
  | Ptyp_arrow (((Labelled _ | Optional _) as label), argument, result) ->
      { typ with ptyp_desc = Ptyp_arrow (label, argument, with_unit result) }
  | Ptyp_arrow (Nolabel, _, _) -> typ
  | _ ->
      let loc = typ.ptyp_loc in
      [%type: unit -> [%t typ]]

let mapper =
  object (self)
    inherit Scope.mapper as super

    method private frontend =
      {
        Element.name = "melact";
        locals = self#locals;
        definitions = self#definitions;
        map = self#expression;
        wrap = (fun loc child -> [%expr React.of_child [%e child]]);
        unwrap = (fun loc element -> unwrap ~loc element);
        handlers = Element.Closures;
        throwing = Element.Recovers;
        handler =
          (fun loc { requirement; value; _ } ->
            let native = [%expr React.Event.ofNative __melhole_event] in
            match requirement with
            | `Required ->
                [%expr (fun __melhole_event -> [%e value] [%e native])]
            | `Optional ->
                [%expr
                  
                    (fun __melhole_event -> Stdlib.Option.iter (fun handle -> handle [%e native]) [%e value])]);
        style =
          (fun loc requirement value ->
            match requirement with
            | `Required -> [%expr (ReactDOM.Style.declarations [%e value])]
            | `Optional ->
                [%expr
                  
                    (Stdlib.Option.fold ~none:[] ~some:ReactDOM.Style.declarations [%e value])]);
        reference =
          (fun loc requirement value ->
            match requirement with
            | `Required -> [%expr (ReactDOM.Ref.identity [%e value], ReactDOM.Ref.attach [%e value])]
            | `Optional ->
                [%expr
                  ( Stdlib.Option.fold ~none:ReactDOM.Ref.absent ~some:ReactDOM.Ref.identity [%e value],
                    Stdlib.Option.fold ~none:ignore ~some:ReactDOM.Ref.attach [%e value] )]);
        inner_html =
          (fun loc value ->
            match !Element.output with
            | Element.Server -> [%expr ReactDOM.html_of [%e value]]
            | Element.Client_only | Element.Hydratable -> [%expr Melhole.View.html_of [%e value]]);
        ids = Element.Tree_ids;
        classify = react_text;
        extra = (fun _ -> None);
        each =
          (fun loc item ->
            let rec piped expression =
              match expression.pexp_desc with
              | Pexp_apply
                  ( { pexp_desc = Pexp_ident { txt = Lident (("|." | "|>") as pipe); _ }; _ },
                    [ (Nolabel, subject); (Nolabel, step) ] ) ->
                  let subject = piped subject in
                  let applied =
                    match (pipe, step.pexp_desc) with
                    | "|.", Pexp_apply (callee, arguments) -> Pexp_apply (callee, (Nolabel, subject) :: arguments)
                    | _, Pexp_apply (callee, arguments) -> Pexp_apply (callee, arguments @ [ (Nolabel, subject) ])
                    | _, _ -> Pexp_apply (step, [ (Nolabel, subject) ])
                  in
                  { expression with pexp_desc = applied }
              | Pexp_apply
                  ( {
                      pexp_desc =
                        Pexp_apply
                          ( { pexp_desc = Pexp_ident { txt = Lident "|."; _ }; _ },
                            [ (Nolabel, subject); (Nolabel, step) ] );
                      _;
                    },
                    arguments ) ->
                  { expression with pexp_desc = Pexp_apply (step, (Nolabel, piped subject) :: arguments) }
              | _ -> expression
            in
            let mapping =
              match (piped item).pexp_desc with
              | Pexp_apply
                  ( { pexp_desc = Pexp_ident { txt = Ldot (Lident "React", (("array" | "list") as shown)); _ }; _ },
                    [ (Nolabel, inner) ] ) -> (
                  let rec flattened expression =
                    match expression.pexp_desc with
                    | Pexp_apply ({ pexp_desc = Pexp_apply (callee, first); _ }, rest) ->
                        flattened { expression with pexp_desc = Pexp_apply (callee, first @ rest) }
                    | _ -> expression
                  in
                  match (flattened (piped inner)).pexp_desc with
                  | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, arguments) -> (
                      let path = match Longident.flatten_exn txt with path -> path | exception Invalid_argument _ -> [] in
                      let unlabelled = List.filter_map (fun (label, value) -> match label with Nolabel -> Some value | Labelled _ | Optional _ -> None) arguments in
                      let given =
                        match (path, arguments, unlabelled) with
                        | (["Array"; "map"] | ["Stdlib"; "Array"; "map"] | ["List"; "map"] | ["Stdlib"; "List"; "map"]), [ _; _ ], [ row; items ]
                          ->
                            Some (path, row, items)
                        | ["Belt"; "Array"; "map"], [ _; _ ], [ items; row ]
                          ->
                            Some (path, row, items)
                        | (["Array"; "mapi"] | ["Stdlib"; "Array"; "mapi"]), [ _; _ ], [ row; items ]
                          ->
                            Some (path, row, items)
                        | ["Belt"; "Array"; "mapWithIndex"], [ _; _ ], [ items; row ] ->
                            Some (path, row, items)
                        | (["Js"; "Array"; "map"] | ["Js"; "Array"; "mapi"]), [ _; _ ], [ items ] ->
                            Option.map
                              (fun row -> (path, row, items))
                              (List.find_map
                                 (fun (label, value) -> match label with Labelled "f" -> Some value | Nolabel | Labelled _ | Optional _ -> None)
                                 arguments)
                        | _ -> None
                      in
                      let swapped row =
                        match row.pexp_desc with
                        | Pexp_function ([ item; index ], None, body) -> Some { row with pexp_desc = Pexp_function ([ index; item ], None, body) }
                        | _ -> None
                      in
                      match (shown, given) with
                      | "array", Some ((["Array"; "map"] | ["Stdlib"; "Array"; "map"] | ["Belt"; "Array"; "map"] | ["Js"; "Array"; "map"]), row, items) ->
                          Some (Element.Items, row, self#expression items)
                      | "array", Some ((["Array"; "mapi"] | ["Stdlib"; "Array"; "mapi"] | ["Belt"; "Array"; "mapWithIndex"]), row, items) ->
                          Some (Element.Numbered, row, self#expression items)
                      | "array", Some (["Js"; "Array"; "mapi"], row, items) ->
                          Option.map (fun row -> (Element.Numbered, row, self#expression items)) (swapped row)
                      | "list", Some ((["List"; "map"] | ["Stdlib"; "List"; "map"]), row, items) ->
                          Some (Element.Items, row, [%expr Stdlib.Array.of_list [%e self#expression items]])
                      | _, (Some _ | None) -> None)
                  | _ -> None)
              | _ -> None
            in
            let unnumbered (numbering, row, items) =
              match (numbering, row.pexp_desc) with
              | Element.Numbered, Pexp_function ([ { pparam_desc = Pparam_val (Nolabel, None, position); _ }; item ], None, body)
                -> (
                  let by_item = { row with pexp_desc = Pexp_function ([ item ], None, body) } in
                  match Free.of_expression by_item with
                  | Reads read when not (List.exists (fun name -> List.mem name read) (Free.bound position)) ->
                      (Element.Items, by_item, items)
                  | Reads _ | Volatile -> (numbering, row, items))
              | (Element.Items | Element.Numbered), _ -> (numbering, row, items)
            in
            Option.bind (Option.map unnumbered mapping) (fun (numbering, row, items) ->
                Element.loop self#frontend ~loc ~definitions:self#definitions
                  ~view:(fun expression ->
                    match expression.pexp_desc with
                    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (Lident "React", _); _ }; _ }, _)
                    | Pexp_construct ({ txt = Lident ("::" | "[]"); _ }, _) ->
                        true
                    | _ -> false)
                  ~stable:[]
                  ~render:(fun element -> [%expr React.to_child [%e element]])
                  ~numbering row items));
      }

    method! attribute attribute =
      match String.equal attribute.attr_name.txt inline_fact with true -> attribute | false -> super#attribute attribute

    val mutable react : opened = Closed
    val mutable modules : string list = []
    val mutable hooks : string list = []

    method! structure items =
      let saved = react and known = hooks in
      let mapped = Hoist.structure self#structure_item items in
      react <- saved;
      hooks <- known;
      mapped

    method! module_binding binding =
      let saved = modules in
      modules <- Option.fold ~none:modules ~some:(fun name -> name :: modules) binding.pmb_name.txt;
      match super#module_binding binding with
      | mapped ->
          modules <- saved;
          mapped
      | exception error ->
          modules <- saved;
          raise error

    method! structure_item item =
      match item.pstr_desc with
      | Pstr_open { popen_expr = { pmod_desc = Pmod_ident { txt = Lident "React"; _ }; _ }; _ }
      | Pstr_include { pincl_mod = { pmod_desc = Pmod_ident { txt = Lident "React"; _ }; _ }; _ } ->
          react <- Opened;
          item
      | Pstr_module { pmb_name = { txt = Some name; _ }; pmb_expr; _ }
        when (match pmb_expr.pmod_desc with
             | Pmod_ident { txt = Lident "React"; _ } -> true
             | Pmod_structure items ->
                 List.exists
                   (fun inner ->
                     match inner.pstr_desc with
                     | Pstr_include { pincl_mod = { pmod_desc = Pmod_ident { txt = Lident "React"; _ }; _ }; _ } -> true
                     | _ -> false)
                   items
             | _ -> false) ->
          hooks <- name :: hooks;
          super#structure_item item
      | Pstr_primitive description
        when List.exists (fun attribute -> String.equal attribute.attr_name.txt "react.component") description.pval_attributes ->
          Location.raise_errorf ~loc:item.pstr_loc
            "melact: [@react.component] external binds a component of a JavaScript React library. It is React \
             code and needs React itself to render; Melact cannot run it. Write the component in Reason or \
             OCaml, or keep this part of the app on reason-react."
      | Pstr_value (flag, bindings) -> (
          let expanded = List.map self#component bindings in
          match List.concat_map (fun (types, _, _) -> types) expanded with
          | [] -> super#structure_item item
          | types ->
              let loc = item.pstr_loc in
              super#structure_item
                (pstr_include ~loc
                   (include_infos ~loc
                      (pmod_structure ~loc
                         (types
                         @ [ { item with pstr_desc = Pstr_value (flag, List.map (fun (_, value, _) -> value) expanded) } ]
                         @ List.concat_map (fun (_, _, makes) -> makes) expanded)))))
      | _ -> super#structure_item item

    method! signature items =
      List.concat_map
        (fun item ->
          match item.psig_desc with
          | Psig_value description ->
              Option.fold
                ~none:[ super#signature_item item ]
                ~some:(fun _ ->
                  let loc = item.psig_loc in
                  let name = description.pval_name.txt in
                  let props = ptyp_constr ~loc { loc; txt = Lident (props_type name) } [] in
                  let rec given typ =
                    match typ.ptyp_desc with
                    | Ptyp_arrow (((Labelled _ | Optional _) as label), argument, result) ->
                        ptyp_arrow ~loc label argument (given result)
                    | _ -> [%type: ?key:string -> unit -> [%t props]]
                  in
                  [
                    psig_type ~loc Recursive
                      [
                        type_declaration ~loc ~name:{ loc; txt = props_type name } ~params:[] ~cstrs:[] ~kind:Ptype_abstract
                          ~private_:Public ~manifest:None;
                      ];
                    psig_value ~loc
                      (value_description ~loc ~name:{ loc; txt = props_name name }
                         ~type_:(given (with_unit description.pval_type)) ~prim:[]);
                    psig_value ~loc
                      (value_description ~loc ~name:{ loc; txt = name } ~type_:[%type: [%t props] -> React.element]
                         ~prim:[ "%identity" ]);
                  ])
                (without_component description.pval_attributes)
          | _ -> [ super#signature_item item ])
        items

    method private component binding =
      Option.fold ~none:([], binding, [])
        ~some:(fun attributes ->
          let loc = binding.pvb_loc in
          let file =
            String.capitalize_ascii
              (Filename.remove_extension (Filename.basename loc.loc_start.pos_fname))
          in
          let name =
            match binding.pvb_pat.ppat_desc with
            | Ppat_var { txt; _ } | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _)
              ->
                txt
            | _ ->
                Location.raise_errorf ~loc
                  "melact: [@react.component] needs a plain name, like make"
          in
          let type_name = props_type name in
          let props_constructor = String.capitalize_ascii type_name in
          let builder =
            component ~loc ~name:(String.concat "." ((file :: List.rev modules) @ [ name ])) ~props_constructor binding.pvb_expr
          in
          ( [
              pstr_type ~loc Recursive
                [
                  {
                    (type_declaration ~loc ~name:{ loc; txt = type_name } ~params:[] ~cstrs:[]
                       ~kind:
                         (Ptype_variant
                            [
                              constructor_declaration ~loc ~name:{ loc; txt = props_constructor }
                                ~args:(Pcstr_tuple [ [%type: React.element] ])
                                ~res:None;
                            ])
                       ~private_:Public ~manifest:None)
                    with
                    ptype_attributes = [ attribute ~loc ~name:{ loc; txt = "unboxed" } ~payload:(PStr []) ];
                  };
                ];
            ],
            {
              binding with
              pvb_pat = pvar ~loc (props_name name);
              pvb_attributes = List.filter (fun attribute -> not (String.equal attribute.attr_name.txt inline_fact)) attributes;
              pvb_expr = builder;
            },
            [
              pstr_primitive ~loc
                {
                  (value_description ~loc ~name:{ loc; txt = name }
                     ~type_:[%type: [%t ptyp_constr ~loc { loc; txt = Lident type_name } []] -> React.element]
                     ~prim:[ "%identity" ])
                  with
                  pval_attributes = List.filter (fun attribute -> String.equal attribute.attr_name.txt inline_fact) attributes;
                };
            ] ))
        (without_component binding.pvb_attributes)

    method! expression expression =
      let loc = expression.pexp_loc in
      match expression.pexp_desc with
      | Pexp_ident { txt = Ldot (Lident "React", name) | Lident name; _ }
        when List.exists (String.equal name) keyed_hooks
             && (match (expression.pexp_desc, react) with
                | Pexp_ident { txt = Ldot _; _ }, _ -> true
                | Pexp_ident { txt = Lident _; _ }, Opened -> not (List.mem name self#locals)
                | _ -> false) ->
          self#keyed expression
      | Pexp_ident { txt = Ldot (Ldot (Lident "React", "Experimental"), name); _ }
        when List.exists (String.equal name) experimental_hooks ->
          self#keyed expression
      | Pexp_ident { txt = Ldot (Lident "Experimental", name); _ }
        when List.exists (String.equal name) experimental_hooks && (match react with Opened -> true | Closed -> false) ->
          self#keyed expression
      | Pexp_ident { txt = Ldot (Lident owner, name); _ }
        when List.exists (String.equal name) keyed_hooks
             && (List.mem owner hooks || List.mem owner !hook_modules) ->
          self#keyed expression
      | Pexp_open ({ popen_expr = { pmod_desc = Pmod_ident { txt = Lident "React"; _ }; _ }; _ }, _) ->
          let saved = react in
          react <- Opened;
          let mapped = super#expression expression in
          react <- saved;
          mapped
      | Pexp_apply (callee, arguments)
        when List.exists (fun attribute -> String.equal attribute.attr_name.txt "melact.keyed") expression.pexp_attributes ->
          {
            expression with
            pexp_desc = Pexp_apply (callee, List.map (fun (label, argument) -> (label, self#expression argument)) arguments);
            pexp_attributes = [];
          }
      | Pexp_apply (callee, arguments) -> (
          match (Element.without_jsx expression.pexp_attributes, callee.pexp_desc) with
          | None, _ -> super#expression expression
          | Some attributes, Pexp_ident { txt = Lident tag; _ } ->
              Element.lowercase self#frontend ~loc ~attributes tag arguments
          | Some _, Pexp_ident { txt = Ldot (path, name); _ } ->
              self#uppercase ~loc path
                (match name with "createElement" -> "make" | other -> other)
                arguments
          | Some _, _ -> Location.raise_errorf ~loc "melact: JSX needs a tag or a module name")
      | Pexp_construct ({ txt = Lident ("[]" | "::"); _ }, _) -> (
          match Element.without_jsx expression.pexp_attributes with
          | Some _ ->
              Element.fragment self#frontend ~loc
                (Option.value ~default:[] (Element.list_items expression))
          | None -> super#expression expression)
      | _ -> super#expression expression

    method private keyed expression =
      let loc = expression.pexp_loc in
      pexp_apply ~loc expression
        [
          ( Nolabel,
            match !Element.output with
            | Element.Server ->
                [%expr
                  Melact_server.Hook.unchecked
                    [%e Hoist.hoist ~loc "hook" [%expr (Melact_server.Hook.key () : unit Melact_server.Hook.key)]]]
            | Element.Client_only | Element.Hydratable ->
                [%expr
                  Melact_runtime.Hook.unchecked
                    [%e Hoist.hoist ~loc "hook" [%expr (Melact_runtime.Hook.key () : unit Melact_runtime.Hook.key)]]] );
        ]

    method private uppercase ~loc path name arguments =
      let key =
        List.find_map
          (fun (label, value) ->
            match label with
            | Labelled "key" -> Some (self#expression value)
            | Labelled _ | Optional _ | Nolabel -> None)
          arguments
      in
      let passed =
        List.concat_map
          (fun (label, value) ->
            match (label, Element.list_items value) with
            | Labelled "key", _ | Nolabel, _ -> []
            | Labelled "children", Some [] -> []
            | Labelled "children", Some [ only ] -> [ (label, self#expression only) ]
            | Labelled "children", Some items ->
                [
                  ( label,
                    [%expr React.array [%e pexp_array ~loc (List.map self#expression items)]]
                  );
                ]
            | (Labelled _ | Optional _), _ -> [ (label, self#expression value) ])
          arguments
      in
      let call =
        pexp_apply ~loc
          (pexp_ident ~loc { loc; txt = Ldot (path, name) })
          [
            ( Nolabel,
              pexp_apply ~loc
                (pexp_ident ~loc { loc; txt = Ldot (path, props_name name) })
                (passed @ [ (Nolabel, [%expr ()]) ]) );
          ]
      in
      Option.fold ~none:call
        ~some:(fun key ->
          match !Element.output with
          | Element.Server -> [%expr ignore ([%e key] : string); [%e call]]
          | Element.Client_only | Element.Hydratable ->
              [%expr
                React.of_child
                  (Melhole.View.with_key ([%e key] : string) [%e unwrap ~loc call])])
        key
  end

let structure items =
  let loc = Location.none in
  let hooked expression =
    let finder =
      object
        inherit [[ `Hooked | `Pure ]] Ast_traverse.fold as super

        method! expression expression found =
          match (found, expression.pexp_desc) with
          | `Hooked, _ -> `Hooked
          | `Pure, Pexp_ident { txt; _ } -> (
              let name = Longident.last_exn txt in
              match String.length name >= 3 && String.equal (String.sub name 0 3) "use" with
              | true when String.length name = 3 || Char.uppercase_ascii name.[3] = name.[3] -> `Hooked
              | true | false -> `Pure)
          | `Pure, _ -> super#expression expression found
      end
    in
    finder#expression expression `Pure
  in
  let jsx expression = Option.is_some (Element.without_jsx expression.pexp_attributes) in
  let inlinable item =
    match item.pstr_desc with
    | Pstr_value (Nonrecursive, [ binding ])
      when Option.is_some (without_component binding.pvb_attributes)
           && (match binding.pvb_pat.ppat_desc with Ppat_var { txt = "make"; _ } -> true | _ -> false) -> (
        let rec unmemo expression =
          match expression.pexp_desc with
          | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (Lident "React", "memo"); _ }; _ }, [ (Nolabel, inner) ]) ->
              unmemo inner
          | _ -> expression
        in
        match (unmemo binding.pvb_expr).pexp_desc with
        | Pexp_function (params, None, Pfunction_body body) -> (
            let props =
              List.filter_map
                (fun param ->
                  match param.pparam_desc with
                  | Pparam_val (Labelled label, None, { ppat_desc = Ppat_var { txt; _ }; _ })
                    when not (List.mem label [ "key"; "children"; "ref" ]) ->
                      Some (`Prop (label, txt))
                  | Pparam_val (Nolabel, None, { ppat_desc = Ppat_construct ({ txt = Lident "()"; _ }, None); _ }) -> Some `Unit
                  | Pparam_val _ | Pparam_newtype _ -> Some `Other)
                params
            in
            let named = List.filter_map (fun prop -> match prop with `Prop pair -> Some pair | `Unit | `Other -> None) props in
            match
              ( List.exists (fun prop -> match prop with `Other -> true | `Prop _ | `Unit -> false) props,
                hooked body,
                body.pexp_desc,
                jsx body,
                Free.of_expression body )
            with
            | false, `Pure, Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident _; _ }; _ }, _), true, Reads reads ->
                Some (named, body, List.filter (fun name -> not (List.mem_assoc name (List.map (fun (l, v) -> (v, l)) named))) reads)
            | _ -> None)
        | _ -> None)
    | _ -> None
  in
  let annotated items =
    let defined item =
      match item.pstr_desc with
      | Pstr_value (_, bindings) -> List.map (fun name -> (`Value, name)) (List.concat_map (fun binding -> Free.bound binding.pvb_pat) bindings)
      | Pstr_primitive description -> [ (`Value, description.pval_name.txt) ]
      | Pstr_type (_, declarations) ->
          List.concat_map
            (fun declaration ->
              (`Type, declaration.ptype_name.txt)
              :: (match declaration.ptype_kind with
                 | Ptype_variant constructors -> List.map (fun constructor -> (`Constructor, constructor.pcd_name.txt)) constructors
                 | Ptype_record labels -> List.map (fun label -> (`Field, label.pld_name.txt)) labels
                 | Ptype_abstract | Ptype_open -> []))
            declarations
      | Pstr_module { pmb_name = { txt = Some name; _ }; _ } -> [ (`Module, name) ]
      | Pstr_exception exception_ -> [ (`Constructor, exception_.ptyexn_constructor.pext_name.txt) ]
      | _ -> []
    in
    let fact names named body =
      let among space = List.filter_map (fun (kind, name) -> match kind = space with true -> Some name | false -> None) names in
      let values = among `Value and modules = among `Module in
      let binders =
        let collector =
          object
            inherit [string list] Ast_traverse.fold as super

            method! pattern pattern found =
              super#pattern pattern (match pattern.ppat_desc with Ppat_var { txt; _ } | Ppat_alias (_, { txt; _ }) -> txt :: found | _ -> found)
          end
        in
        List.map snd named @ collector#expression body []
      in
      match List.exists (fun binder -> List.mem binder values) binders with
      | true -> None
      | false ->
          let rec moduled lid =
            match lid with
            | Lident name when List.mem name modules -> Ldot (Lident own_module, name)
            | Lident _ | Lapply _ -> lid
            | Ldot (inner, name) -> Ldot (moduled inner, name)
          in
          let own space (located : longident loc) =
            {
              located with
              txt =
                (match located.txt with
                | Lident name when List.mem name (among space) -> Ldot (Lident own_module, name)
                | Lident _ | Lapply _ -> located.txt
                | Ldot (inner, name) -> Ldot (moduled inner, name));
            }
          in
          let qualified =
            (object
               inherit Ast_traverse.map as super

               method! expression expression =
                 let expression = super#expression expression in
                 match expression.pexp_desc with
                 | Pexp_ident name -> { expression with pexp_desc = Pexp_ident (own `Value name) }
                 | Pexp_construct (name, argument) -> { expression with pexp_desc = Pexp_construct (own `Constructor name, argument) }
                 | Pexp_field (record, name) -> { expression with pexp_desc = Pexp_field (record, own `Field name) }
                 | Pexp_setfield (record, name, value) -> { expression with pexp_desc = Pexp_setfield (record, own `Field name, value) }
                 | Pexp_record (fields, base) ->
                     { expression with pexp_desc = Pexp_record (List.map (fun (name, value) -> (own `Field name, value)) fields, base) }
                 | _ -> expression

               method! pattern pattern =
                 let pattern = super#pattern pattern in
                 match pattern.ppat_desc with
                 | Ppat_construct (name, argument) -> { pattern with ppat_desc = Ppat_construct (own `Constructor name, argument) }
                 | Ppat_record (fields, closed) ->
                     { pattern with ppat_desc = Ppat_record (List.map (fun (name, value) -> (own `Field name, value)) fields, closed) }
                 | _ -> pattern

               method! core_type core_type =
                 let core_type = super#core_type core_type in
                 match core_type.ptyp_desc with
                 | Ptyp_constr (name, arguments) -> { core_type with ptyp_desc = Ptyp_constr (own `Type name, arguments) }
                 | _ -> core_type
            end)
              #expression body
          in
          let loc = body.pexp_loc in
          let lambda =
            {
              body with
              pexp_desc =
                Pexp_function
                  ( List.map
                      (fun (label, variable) -> { pparam_loc = loc; pparam_desc = Pparam_val (Labelled label, None, pvar ~loc variable) })
                      named,
                    None,
                    Pfunction_body qualified );
              pexp_attributes = [];
            }
          in
          Some
            (attribute ~loc ~name:{ loc; txt = inline_fact }
               ~payload:(PStr [ pstr_eval ~loc (pexp_tuple ~loc [ eint ~loc inline_version; lambda ]) [] ]))
    in
    match List.exists (fun item -> match item.pstr_desc with Pstr_open _ | Pstr_include _ -> true | _ -> false) items with
    | true -> items
    | false ->
        List.rev
          (snd
             (List.fold_left
                (fun (names, done_) item ->
                  let item =
                    match (item.pstr_desc, inlinable item) with
                    | Pstr_value (flag, [ binding ]), Some (named, body, _) ->
                        Option.fold ~none:item
                          ~some:(fun attribute ->
                            { item with pstr_desc = Pstr_value (flag, [ { binding with pvb_attributes = attribute :: binding.pvb_attributes } ]) })
                          (fact names named body)
                    | _ -> item
                  in
                  (defined item @ names, item :: done_))
                ([], []) items))
  in
  let environment = lazy (match Ocaml_common.Compmisc.initial_env () with environment -> Some environment | exception _ -> None) in
  let imported path =
    match Option.bind (Longident.flatten_exn (Ldot (path, "make")) |> Ocaml_common.Longident.unflatten) (fun lid -> Option.map (fun environment -> (lid, environment)) (Lazy.force environment)) with
    | None -> None
    | Some (lid, environment) -> (
        match Ocaml_common.Env.lookup_value ~use:false ~loc:Ocaml_common.Location.none lid environment with
        | exception _ -> None
        | _, description ->
            List.find_map
              (fun (attribute : Ocaml_common.Typedtree.attribute) ->
                match (attribute.attr_name.txt, attribute.attr_payload) with
                | name, PStr payload when String.equal name inline_fact -> (
                    match Ppxlib_ast.Selected_ast.of_ocaml Structure payload with
                    | [
                     {
                       pstr_desc =
                         Pstr_eval
                           ( {
                               pexp_desc =
                                 Pexp_tuple
                                   [ { pexp_desc = Pexp_constant (Pconst_integer (version, None)); _ }; lambda ];
                               _;
                             },
                             _ );
                       _;
                     };
                    ]
                      when int_of_string version = inline_version -> (
                        let rec resolved lid =
                          match lid with
                          | Lident name when String.equal name own_module -> path
                          | Lident _ -> lid
                          | Ldot (inner, name) -> Ldot (resolved inner, name)
                          | Lapply (left, right) -> Lapply (resolved left, resolved right)
                        in
                        let lambda =
                          (object
                             inherit Ast_traverse.map
                             method! longident lid = resolved lid
                          end)
                            #expression lambda
                        in
                        match lambda.pexp_desc with
                        | Pexp_function (params, None, Pfunction_body body) -> (
                            let named =
                              List.filter_map
                                (fun param ->
                                  match param.pparam_desc with
                                  | Pparam_val (Labelled label, None, { ppat_desc = Ppat_var { txt; _ }; _ }) -> Some (label, txt)
                                  | Pparam_val _ | Pparam_newtype _ -> None)
                                params
                            in
                            match Free.of_expression body with
                            | Reads reads when List.length named = List.length params ->
                                Some (named, body, List.filter (fun read -> not (List.mem read (List.map snd named))) reads)
                            | Reads _ | Volatile -> None)
                        | _ -> None)
                    | _ -> None
                    | exception _ -> None)
                | _ -> None)
              description.val_attributes)
    | exception Invalid_argument _ -> None
  in
  let inliner =
    object (self)
      inherit Scope.mapper as super
      val mutable known : (string * ((string * string) list * expression * string list)) list = []
      val mutable shadowed : (string * string list) list = []
      val mutable toplevel : string list = []

      method! attribute attribute =
        match String.equal attribute.attr_name.txt inline_fact with true -> attribute | false -> super#attribute attribute

      method! structure_item item =
        let mapped = super#structure_item item in
        (match mapped.pstr_desc with
        | Pstr_module { pmb_name = { txt = Some name; _ }; pmb_expr = { pmod_desc = Pmod_structure [ single ]; _ }; _ } ->
            known <- List.remove_assoc name known;
            shadowed <- List.remove_assoc name shadowed;
            Option.iter
              (fun component ->
                known <- (name, component) :: known;
                shadowed <- (name, []) :: shadowed)
              (inlinable single)
        | Pstr_module { pmb_name = { txt = Some name; _ }; _ } ->
            known <- List.remove_assoc name known;
            shadowed <- List.remove_assoc name shadowed
        | Pstr_value (_, bindings) ->
            let names = List.concat_map (fun binding -> Free.bound binding.pvb_pat) bindings in
            toplevel <- names @ toplevel;
            shadowed <- List.map (fun (name, list) -> (name, names @ list)) shadowed
        | _ -> ());
        mapped

      method private expanded expression =
        match expression.pexp_desc with
        | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (path, "createElement"); _ }; _ }, arguments)
          when jsx expression -> (
            let found =
              match path with
              | Lident name -> (
                  match List.assoc_opt name known with
                  | Some (named, body, reads) -> Some (named, body, reads, Option.value ~default:[] (List.assoc_opt name shadowed))
                  | None -> Option.map (fun (named, body, reads) -> (named, body, reads, toplevel)) (imported path))
              | Ldot _ | Lapply _ -> Option.map (fun (named, body, reads) -> (named, body, reads, toplevel)) (imported path)
            in
            match found with
            | None -> None
            | Some (named, body, reads, blocked) -> (
                let given =
                  List.filter_map
                    (fun (label, value) -> match label with Labelled label | Optional label -> Some (label, value) | Nolabel -> None)
                    arguments
                in
                let children_empty =
                  match List.assoc_opt "children" given with
                  | None | Some { pexp_desc = Pexp_construct ({ txt = Lident "[]"; _ }, None); _ } -> `Empty
                  | Some _ -> `Given
                in
                let props = List.filter (fun (label, _) -> not (List.mem label [ "key"; "children" ])) given in
                let exact =
                  List.length props = List.length named
                  && List.for_all (fun (label, _) -> List.mem_assoc label props) named
                  && List.for_all (fun (label, _) -> List.mem_assoc label named) props
                  && List.for_all (fun (label, _) -> match label with Labelled _ | Nolabel -> true | Optional _ -> false) arguments
                in
                let clear =
                  List.for_all
                    (fun read ->
                      not (List.mem read self#locals || List.mem read blocked))
                    reads
                in
                match (children_empty, exact, clear) with
                | `Empty, true, true ->
                    let keyed =
                      Option.fold ~none:body
                        ~some:(fun key ->
                          match body.pexp_desc with
                          | Pexp_apply (tag, tag_arguments) ->
                              { body with pexp_desc = Pexp_apply (tag, (Labelled "key", key) :: tag_arguments) }
                          | _ -> body)
                        (List.assoc_opt "key" given)
                    in
                    let loc = expression.pexp_loc in
                    Some
                      (match named with
                      | [] -> keyed
                      | _ :: _ ->
                          pexp_let ~loc Nonrecursive
                            (List.map
                               (fun (label, variable) -> value_binding ~loc ~pat:(pvar ~loc variable) ~expr:(List.assoc label props))
                               named)
                            keyed)
                | (`Empty | `Given), _, _ -> None))
        | _ -> None

      method! expression expression =
        let in_place item = Option.value ~default:item (self#expanded item) in
        let mapping callee =
          match callee.pexp_desc with
          | Pexp_ident { txt; _ }
          | Pexp_apply
              ( { pexp_desc = Pexp_ident { txt = Lident ("|." | "|>"); _ }; _ },
                [ _; (Nolabel, { pexp_desc = Pexp_ident { txt; _ }; _ }) ] )
          | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _) -> (
              match Longident.flatten_exn txt with
              | ["Array"; ("map" | "mapi")] | ["Stdlib"; "Array"; ("map" | "mapi")] | ["List"; ("map" | "mapi")]
              | ["Stdlib"; "List"; ("map" | "mapi")] | ["Belt"; "Array"; ("map" | "mapWithIndex")]
              | ["Js"; "Array"; ("map" | "mapi")] ->
                  `Mapping
              | _ -> `Other
              | exception Invalid_argument _ -> `Other)
          | _ -> `Other
        in
        match expression.pexp_desc with
        | Pexp_apply (callee, arguments) when mapping callee = `Mapping ->
            super#expression
              {
                expression with
                pexp_desc =
                  Pexp_apply
                    ( callee,
                      List.map
                        (fun (label, value) ->
                          match value.pexp_desc with
                          | Pexp_function (params, constraint_, Pfunction_body body) ->
                              (label, { value with pexp_desc = Pexp_function (params, constraint_, Pfunction_body (in_place body)) })
                          | _ -> (label, value))
                        arguments );
              }
        | _ -> super#expression expression
    end
  in
  [%stri [@@@alert "-hook"]] :: [%stri let () = React.reason_react_is_also_in_this_build_remove_it ()]
  :: mapper#structure (inliner#structure (annotated items))
let signature items = mapper#signature items
let () =
  Driver.add_arg "-hook-modules"
    (Arg.String (fun names -> hook_modules := String.split_on_char ',' names @ !hook_modules))
    ~doc:" modules whose use… functions are React's hooks, like a module that includes React (comma separated)"

let () =
  Driver.add_arg "-hydratable"
    (Arg.Unit (fun () -> Element.output := Element.Hydratable))
    ~doc:" compile templates that can take over server-rendered HTML"

let () =
  Driver.add_arg "-server"
    (Arg.Unit (fun () -> Element.output := Element.Server))
    ~doc:" compile components to code that writes their HTML, for melact.server, natively or under Melange"

let () =
  Driver.register_transformation "melact"
    ~instrument:(Driver.Instrument.make Npm_react.structure ~position:Before)
    ~impl:structure ~intf:signature
