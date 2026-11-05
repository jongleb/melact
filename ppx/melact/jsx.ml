open Ppxlib
open Melhole_compiler
open Ast_builder.Default

let keyed_hooks =
  [
    "useState"; "useReducer"; "useReducerWithMapState"; "useRef"; "useId"; "useEffect";
    "useLayoutEffect"; "useMemo"; "useCallback"; "useInsertionEffect"; "useSyncExternalStore";
  ]
  @ List.concat_map
      (fun base -> List.init 8 (fun arity -> base ^ string_of_int arity))
      [
        "useEffect"; "useLayoutEffect"; "useInsertionEffect"; "useMemo"; "useCallback";
        "useImperativeHandle";
      ]

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

let component ~loc ~name expression =
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
  let aliased =
    List.map
      (fun param ->
        match (param.pparam_desc, !next) with
        | Pparam_val (((Labelled _ | Optional _) as label), default, pattern), name :: rest
          ->
            next := rest;
            {
              param with
              pparam_desc =
                Pparam_val (label, default, ppat_alias ~loc pattern { loc; txt = name });
            }
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
  let definition =
    Hoist.hoist ~loc "component" [%expr Melact_runtime.Component.make ~name:[%e estring ~loc name]]
  in
  let inputs =
    pexp_array ~loc
      (List.map (fun name -> [%expr Melhole.View.Input [%e evar ~loc name]]) names)
  in
  let kind =
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
    finder#expression body `Pure
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
  let props =
    let given =
      List.mapi
        (fun index label -> (label, Printf.sprintf "__melhole_given_%d" index))
        (List.filter_map
           (fun param ->
             match param.pparam_desc with
             | Pparam_val (((Labelled _ | Optional _) as label), _, _) -> Some label
             | Pparam_val (Nolabel, _, _) | Pparam_newtype _ -> None)
           complete)
    in
    pexp_function ~loc
      (List.map
         (fun (label, name) -> { pparam_loc = loc; pparam_desc = Pparam_val (label, None, pvar ~loc name) })
         given
      @ [
          { pparam_loc = loc; pparam_desc = Pparam_val (Optional "key", None, [%pat? __melhole_key]) };
          { pparam_loc = loc; pparam_desc = Pparam_val (Nolabel, None, [%pat? ()]) };
          { pparam_loc = loc; pparam_desc = Pparam_val (Nolabel, None, [%pat? __melhole_make]) };
        ])
      None
      (Pfunction_body
         [%expr
           let __melhole_element =
             [%e
               pexp_apply ~loc [%expr __melhole_make]
                 (List.map (fun (label, name) -> (label, evar ~loc name)) given @ [ (Nolabel, [%expr ()]) ])]
           in
           Option.fold ~none:__melhole_element
             ~some:(fun key -> React.of_child (Melhole.View.with_key key (React.to_child __melhole_element)))
             __melhole_key])
  in
  ( pexp_function ~loc complete None
    (Pfunction_body
       (match kind with
       | `Stateful ->
           [%expr
             React.of_child
               (Melact_runtime.Instance.component [%e definition] [%e inputs] (fun () ->
                    [%e unwrap ~loc checked]))]
       | `Pure ->
           [%expr
             React.of_child
               (Melhole.View.pure [%e definition] [%e inputs] (fun () -> [%e unwrap ~loc body]))])),
    props )

let props_name name = match name with "make" -> "makeProps" | other -> other ^ "Props"

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
        map = self#expression;
        wrap = (fun loc child -> [%expr React.of_child [%e child]]);
        unwrap = (fun loc element -> unwrap ~loc element);
        handlers = Element.Closures;
        handler =
          (fun loc { requirement; value; _ } ->
            let native = [%expr React.Event.ofNative __melhole_event] in
            match requirement with
            | `Required ->
                [%expr (fun __melhole_event -> [%e value] [%e native])]
            | `Optional ->
                [%expr
                  
                    (fun __melhole_event -> Option.iter (fun handle -> handle [%e native]) [%e value])]);
        style =
          (fun loc requirement value ->
            match requirement with
            | `Required -> [%expr (ReactDOM.Style.declarations [%e value])]
            | `Optional ->
                [%expr
                  
                    (Option.fold ~none:[] ~some:ReactDOM.Style.declarations [%e value])]);
        reference =
          (fun loc requirement value ->
            match requirement with
            | `Required -> [%expr (ReactDOM.Ref.attach [%e value])]
            | `Optional ->
                [%expr
                  
                    (Option.fold ~none:ignore ~some:ReactDOM.Ref.attach [%e value])]);
        classify = react_text;
        extra = (fun _ -> None);
        each =
          (fun loc item ->
            let mapping =
              match item.pexp_desc with
              | Pexp_apply
                  ( { pexp_desc = Pexp_ident { txt = Ldot (Lident "React", "array"); _ }; _ },
                    [ (Nolabel, { pexp_desc = Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, arguments); _ }) ] )
                -> (
                  match (txt, arguments) with
                  | Ldot (Lident "Array", "map"), [ (Nolabel, row); (Nolabel, items) ]
                  | Ldot (Ldot (Lident "Belt", "Array"), "map"), [ (Nolabel, items); (Nolabel, row) ] ->
                      Some (row, self#expression items)
                  | _ -> None)
              | Pexp_apply
                  ( { pexp_desc = Pexp_ident { txt = Ldot (Lident "React", "list"); _ }; _ },
                    [
                      ( Nolabel,
                        {
                          pexp_desc =
                            Pexp_apply
                              ( { pexp_desc = Pexp_ident { txt = Ldot (Lident "List", "map"); _ }; _ },
                                [ (Nolabel, row); (Nolabel, items) ] );
                          _;
                        } );
                    ] ) ->
                  Some (row, [%expr Array.of_list [%e self#expression items]])
              | _ -> None
            in
            Option.bind mapping (fun (row, items) ->
                Element.loop self#frontend ~loc ~definitions:self#definitions
                  ~view:(fun expression ->
                    match expression.pexp_desc with
                    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (Lident "React", _); _ }; _ }, _)
                    | Pexp_construct ({ txt = Lident ("::" | "[]"); _ }, _) ->
                        true
                    | _ -> false)
                  ~stable:[]
                  ~render:(fun element -> [%expr React.to_child [%e element]])
                  row items));
      }

    method! structure items = Hoist.structure self#structure_item items

    method! structure_item item =
      match item.pstr_desc with
      | Pstr_value (flag, bindings) ->
          super#structure_item
            { item with pstr_desc = Pstr_value (flag, List.concat_map self#component bindings) }
      | _ -> super#structure_item item

    method! signature items =
      List.concat_map
        (fun item ->
          match item.psig_desc with
          | Psig_value description ->
              Option.fold
                ~none:[ super#signature_item item ]
                ~some:(fun attributes ->
                  let loc = item.psig_loc in
                  let make = with_unit description.pval_type in
                  let rec given typ =
                    match typ.ptyp_desc with
                    | Ptyp_arrow (((Labelled _ | Optional _) as label), argument, result) ->
                        ptyp_arrow ~loc label argument (given result)
                    | _ -> [%type: ?key:string -> unit -> [%t make] -> React.element]
                  in
                  [
                    { item with psig_desc = Psig_value { description with pval_type = make; pval_attributes = attributes } };
                    psig_value ~loc
                      (value_description ~loc
                         ~name:{ loc; txt = props_name description.pval_name.txt }
                         ~type_:(given make) ~prim:[]);
                  ])
                (without_component description.pval_attributes)
          | _ -> [ super#signature_item item ])
        items

    method private component binding =
      Option.fold ~none:[ binding ]
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
          let make, props = component ~loc ~name:(file ^ "." ^ name) binding.pvb_expr in
          [
            { binding with pvb_attributes = attributes; pvb_expr = make };
            {
              (value_binding ~loc ~pat:(pvar ~loc (props_name name)) ~expr:props) with
              pvb_attributes =
                [ attribute ~loc ~name:{ loc; txt = "warning" } ~payload:(PStr [ pstr_eval ~loc (estring ~loc "-32") [] ]) ];
            };
          ])
        (without_component binding.pvb_attributes)

    method! expression expression =
      let loc = expression.pexp_loc in
      match expression.pexp_desc with
      | Pexp_ident { txt = Ldot (Lident "React", name); _ }
        when List.exists (String.equal name) keyed_hooks ->
          pexp_apply ~loc expression
            [ (Nolabel, Hoist.hoist ~loc "hook" [%expr Melact_runtime.Hook.key ()]) ]
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
          (passed @ [ (Nolabel, [%expr ()]) ])
      in
      Option.fold ~none:call
        ~some:(fun key ->
          [%expr
            React.of_child
              (Melhole.View.with_key ([%e key] : string) [%e unwrap ~loc call])])
        key
  end

let structure items =
  let loc = Location.none in
  [%stri [@@@alert "-hook"]] :: mapper#structure items
let signature items = mapper#signature items
let () =
  Driver.add_arg "-hydratable"
    (Arg.Unit (fun () -> Element.output := Element.Hydratable))
    ~doc:" compile templates that can take over server-rendered HTML"

let () =
  Driver.register_transformation "melact" ~preprocess_impl:Npm_react.structure ~impl:structure ~intf:signature
