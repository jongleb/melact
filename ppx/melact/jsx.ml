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
    Hoist.hoist ~loc "component" [%expr Melhole.Component.make ~name:[%e estring ~loc name]]
  in
  let inputs =
    pexp_array ~loc
      (List.map (fun name -> [%expr Melhole.View.Input [%e evar ~loc name]]) names)
  in
  pexp_function ~loc complete None
    (Pfunction_body
       [%expr
         React.of_child
           (Melhole.View.component [%e definition] [%e inputs] (fun () ->
                [%e unwrap ~loc body]))])

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
        handler =
          (fun loc { family; requirement; value; _ } ->
            let native =
              pexp_construct ~loc
                { loc; txt = Ldot (Ldot (Lident "ReactEvent", family), "Native") }
                (Some [%expr __melhole_event])
            in
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
        each = (fun _ _ -> None);
      }

    method! structure items = Hoist.structure self#structure_item items

    method! structure_item item =
      match item.pstr_desc with
      | Pstr_value (flag, bindings) ->
          super#structure_item
            { item with pstr_desc = Pstr_value (flag, List.map self#component bindings) }
      | _ -> super#structure_item item

    method! signature_item item =
      match item.psig_desc with
      | Psig_value description -> (
          match without_component description.pval_attributes with
          | Some attributes ->
              {
                item with
                psig_desc =
                  Psig_value
                    {
                      description with
                      pval_type = with_unit description.pval_type;
                      pval_attributes = attributes;
                    };
              }
          | None -> super#signature_item item)
      | _ -> super#signature_item item

    method private component binding =
      Option.fold ~none:binding
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
          {
            binding with
            pvb_attributes = attributes;
            pvb_expr = component ~loc ~name:(file ^ "." ^ name) binding.pvb_expr;
          })
        (without_component binding.pvb_attributes)

    method! expression expression =
      let loc = expression.pexp_loc in
      match expression.pexp_desc with
      | Pexp_ident { txt = Ldot (Lident "React", name); _ }
        when List.exists (String.equal name) keyed_hooks ->
          pexp_apply ~loc expression
            [ (Nolabel, Hoist.hoist ~loc "hook" [%expr Melhole.Hook.key ()]) ]
      | Pexp_apply (callee, arguments) -> (
          match (Element.without_jsx expression.pexp_attributes, callee.pexp_desc) with
          | None, _ -> super#expression expression
          | Some _, Pexp_ident { txt = Lident tag; _ } ->
              Element.lowercase self#frontend ~loc tag arguments
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

let structure items = mapper#structure items
let signature items = mapper#signature items
let () = Driver.register_transformation "melact" ~impl:structure ~intf:signature
