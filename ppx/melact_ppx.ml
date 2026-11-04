open Ppxlib
open Ast_builder.Default

(** What one DOM prop becomes. *)
type prop =
  | Static of string * Markup.static  (** Written into the template. *)
  | Dynamic of Markup.site * expression  (** A hole and its value. *)
  | Absent

let counter = ref 0
let hoisted = ref []

let keyed_hooks =
  [
    "useState"; "useReducer"; "useReducerWithMapState"; "useRef"; "useId"; "useEffect";
    "useLayoutEffect"; "useMemo"; "useCallback";
  ]
  @ List.concat_map
      (fun base -> List.init 8 (fun arity -> base ^ string_of_int arity))
      [ "useEffect"; "useLayoutEffect"; "useMemo"; "useCallback"; "useImperativeHandle" ]

let hoist ~loc prefix expression =
  incr counter;
  let name = Printf.sprintf "__melact_%s_%d" prefix !counter in
  hoisted := [%stri let [%p pvar ~loc name] = [%e expression]] :: !hoisted;
  evar ~loc name

let without_jsx attributes =
  match
    List.partition (fun attribute -> String.equal attribute.attr_name.txt "JSX") attributes
  with
  | [], _ -> None
  | _ :: _, rest -> Some rest

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
    let (React.Element __melact_child) = [%e element] in
    __melact_child]

let rec list_items expression =
  match expression.pexp_desc with
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> Some []
  | Pexp_construct
      ({ txt = Lident "::"; _ }, Some { pexp_desc = Pexp_tuple [ head; tail ]; _ }) ->
      Option.map (fun rest -> head :: rest) (list_items tail)
  | _ -> None

let lowercase expression =
  match expression.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident tag; _ }; _ }, arguments) ->
      Option.map (fun _ -> (tag, arguments)) (without_jsx expression.pexp_attributes)
  | _ -> None

let react_text expression =
  match expression.pexp_desc with
  | Pexp_apply
      ( {
          pexp_desc =
            Pexp_ident { txt = Ldot (Lident "React", (("string" | "int" | "float") as kind)); _ };
          _;
        },
        [ (Nolabel, value) ] )
  | Pexp_apply
      ( { pexp_desc = Pexp_ident { txt = Lident "|."; _ }; _ },
        [
          (Nolabel, value);
          ( Nolabel,
            {
              pexp_desc =
                Pexp_ident
                  { txt = Ldot (Lident "React", (("string" | "int" | "float") as kind)); _ };
              _;
            } );
        ] ) ->
      Some (kind, value)
  | _ -> None

let prop ~loc kind requirement value =
  let hole site expression = Dynamic (site, expression) in
  let literal =
    match value.pexp_desc with
    | Pexp_constant (Pconst_string (text, _, _)) -> `String text
    | Pexp_constant (Pconst_integer (digits, None)) -> `Number digits
    | Pexp_constant (Pconst_float (digits, None)) -> `Number digits
    | Pexp_construct ({ txt = Lident "true"; _ }, None) -> `True
    | Pexp_construct ({ txt = Lident "false"; _ }, None) -> `False
    | _ -> `Dynamic
  in
  let type_of (value : Dom_props.value) =
    match value with
    | Text -> [%type: string]
    | Flag | Booleanish -> [%type: bool]
    | Integer -> [%type: int]
    | Decimal -> [%type: float]
  in
  match (kind, requirement, literal) with
  | Dom_props.Ignored, _, _ -> Absent
  | Attribute (name, Text), `Required, `String text -> Static (name, Valued text)
  | Attribute (name, Text), `Required, _ ->
      hole (Attr name) [%expr Melact_view.View.HAttr (Some ([%e value] : string))]
  | Attribute (name, Flag), `Required, `True -> Static (name, Bare)
  | Attribute (_, Flag), `Required, `False -> Absent
  | Attribute (name, Flag), `Required, _ ->
      hole (Attr name)
        [%expr Melact_view.View.HAttr (if ([%e value] : bool) then Some "" else None)]
  | Attribute (name, Booleanish), `Required, `True -> Static (name, Valued "true")
  | Attribute (name, Booleanish), `Required, `False -> Static (name, Valued "false")
  | Attribute (name, Booleanish), `Required, _ ->
      hole (Attr name)
        [%expr
          Melact_view.View.HAttr (Some (if ([%e value] : bool) then "true" else "false"))]
  | Attribute (name, (Integer | Decimal)), `Required, `Number digits ->
      Static (name, Valued digits)
  | Attribute (name, Integer), `Required, _ ->
      hole (Attr name)
        [%expr Melact_view.View.HAttr (Some (string_of_int ([%e value] : int)))]
  | Attribute (name, Decimal), `Required, _ ->
      hole (Attr name)
        [%expr Melact_view.View.HAttr (Some (Js.Float.toString ([%e value] : float)))]
  | Attribute (name, Text), `Optional, _ ->
      hole (Attr name) [%expr Melact_view.View.HAttr ([%e value] : string option)]
  | Attribute (name, Flag), `Optional, _ ->
      hole (Attr name)
        [%expr
          Melact_view.View.HAttr
            (match ([%e value] : bool option) with
            | Some true -> Some ""
            | Some false | None -> None)]
  | Attribute (name, Booleanish), `Optional, _ ->
      hole (Attr name)
        [%expr
          Melact_view.View.HAttr
            (Option.map
               (fun flag -> if flag then "true" else "false")
               ([%e value] : bool option))]
  | Attribute (name, Integer), `Optional, _ ->
      hole (Attr name)
        [%expr Melact_view.View.HAttr (Option.map string_of_int ([%e value] : int option))]
  | Attribute (name, Decimal), `Optional, _ ->
      hole (Attr name)
        [%expr
          Melact_view.View.HAttr (Option.map Js.Float.toString ([%e value] : float option))]
  | Property (name, kind), `Required, _ ->
      hole (Prop name) [%expr Melact_view.View.HProp ([%e value] : [%t type_of kind])]
  | Property (name, kind), `Optional, _ ->
      let default =
        match kind with
        | Text -> [%expr ""]
        | Flag | Booleanish -> [%expr false]
        | Integer -> [%expr 0]
        | Decimal -> [%expr 0.]
      in
      hole (Prop name)
        [%expr
          Melact_view.View.HProp
            (Option.value ~default:[%e default] ([%e value] : [%t type_of kind] option))]
  | Handler (event, family), requirement, _ ->
      let native =
        pexp_construct ~loc
          { loc; txt = Ldot (Ldot (Lident "ReactEvent", family), "Native") }
          (Some [%expr __melact_event])
      in
      hole (Handler event)
        (match requirement with
        | `Required ->
            [%expr Melact_view.View.HHandler (fun __melact_event -> [%e value] [%e native])]
        | `Optional ->
            [%expr
              Melact_view.View.HHandler
                (fun __melact_event ->
                  Option.iter (fun handle -> handle [%e native]) [%e value])])
  | Style, `Required, _ ->
      hole Style [%expr Melact_view.View.HStyle (ReactDOM.Style.declarations [%e value])]
  | Style, `Optional, _ ->
      hole Style
        [%expr
          Melact_view.View.HStyle
            (Option.fold ~none:[] ~some:ReactDOM.Style.declarations [%e value])]
  | Ref, `Required, _ ->
      hole Ref
        [%expr
          Melact_view.View.HRef
            (let (ReactDOM.Dom_ref apply) = [%e value] in
             apply)]
  | Ref, `Optional, _ ->
      hole Ref
        [%expr
          Melact_view.View.HRef
            (Option.fold ~none:ignore ~some:(fun (ReactDOM.Dom_ref apply) -> apply) [%e value])]
  | Inner_html, `Required, _ ->
      hole (Prop "innerHTML") [%expr Melact_view.View.HProp [%e value]##__html]
  | Inner_html, `Optional, _ ->
      hole (Prop "innerHTML")
        [%expr
          Melact_view.View.HProp
            (Option.fold ~none:"" ~some:(fun html -> html##__html) [%e value])]

let component ~loc ~name expression =
  let rec gather expression =
    match expression.pexp_desc with
    | Pexp_apply
        ( {
            pexp_desc =
              Pexp_ident
                { txt = Ldot (Lident "React", ("memo" | "memoCustomCompareProps")); _ };
            _;
          },
          (Nolabel, inner) :: _ ) ->
        gather inner
    | Pexp_function (params, None, Pfunction_body body) ->
        let more, body = gather body in
        (params @ more, body)
    | Pexp_function (params, Some (Pconstraint result), Pfunction_body body) ->
        (params, pexp_constraint ~loc:body.pexp_loc body result)
    | Pexp_function (_, _, _) ->
        Location.raise_errorf ~loc:expression.pexp_loc
          "melact: a [@react.component] takes labelled arguments and returns an element"
    | _ -> ([], expression)
  in
  let params, body = gather expression in
  let rec trailing params =
    match params with
    | [] -> `Missing
    | [ { pparam_desc = Pparam_val (Nolabel, None, _); _ } ] -> `Present
    | { pparam_desc = Pparam_val (Nolabel, _, _); pparam_loc; _ } :: _ ->
        Location.raise_errorf ~loc:pparam_loc
          "melact: only the last argument of a [@react.component] may be unlabelled"
    | _ :: rest -> trailing rest
  in
  let patterns =
    List.filter_map
      (fun param ->
        match param.pparam_desc with
        | Pparam_val ((Labelled _ | Optional _), _, pattern) -> Some pattern
        | Pparam_val (Nolabel, _, _) | Pparam_newtype _ -> None)
      params
  in
  let names = List.mapi (fun index _ -> Printf.sprintf "__melact_prop_%d" index) patterns in
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
  let props, pattern, unchanged =
    match (names, patterns) with
    | [], _ | _, [] -> ([%expr ()], [%pat? ()], [%expr fun () () -> true])
    | [ name ], [ pattern ] -> (evar ~loc name, pattern, [%expr ( == )])
    | _, _ ->
        let olds = List.map (fun name -> name ^ "_old") names in
        let news = List.map (fun name -> name ^ "_new") names in
        let same =
          List.map2
            (fun old_name new_name -> [%expr [%e evar ~loc old_name] == [%e evar ~loc new_name]])
            olds news
          |> List.rev
          |> function
          | [] -> [%expr true]
          | last :: earlier ->
              List.fold_left (fun rest test -> [%expr [%e test] && [%e rest]]) last earlier
        in
        ( pexp_tuple ~loc (List.map (evar ~loc) names),
          ppat_tuple ~loc patterns,
          [%expr
            fun [%p ppat_tuple ~loc (List.map (pvar ~loc) olds)]
                [%p ppat_tuple ~loc (List.map (pvar ~loc) news)] -> [%e same]] )
  in
  let definition =
    hoist ~loc "component"
      [%expr
        Melact_view.Component.make ~name:[%e estring ~loc name] ~unchanged:[%e unchanged]]
  in
  let render =
    [%expr
      React.Element
        (Melact_view.View.component [%e definition] [%e props] (fun [%p pattern] ->
             [%e unwrap ~loc body]))]
  in
  {
    (pexp_function ~loc complete None (Pfunction_body render)) with
    pexp_attributes =
      [
        attribute ~loc ~name:{ loc; txt = "ocaml.warning" }
          ~payload:(PStr [ pstr_eval ~loc (estring ~loc "-26-27") [] ]);
      ];
  }

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
    inherit Ast_traverse.map as super

    method! structure items =
      List.concat_map
        (fun item ->
          let saved = !hoisted in
          hoisted := [];
          let item = self#structure_item item in
          let lifted = List.rev !hoisted in
          hoisted := saved;
          lifted @ [ item ])
        items

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
            [ (Nolabel, hoist ~loc "hook" [%expr Melact_view.Hook.key ()]) ]
      | Pexp_apply (callee, arguments) -> (
          match without_jsx expression.pexp_attributes with
          | Some _ -> self#jsx ~loc callee arguments
          | None -> super#expression expression)
      | Pexp_construct ({ txt = Lident ("[]" | "::"); _ }, _) -> (
          match without_jsx expression.pexp_attributes with
          | Some _ ->
              [%expr
                React.Element
                  (Melact_view.View.list
                     [%e
                       elist ~loc
                         (List.map
                            (fun item -> unwrap ~loc (self#expression item))
                            (Option.value ~default:[] (list_items expression)))])]
          | None -> super#expression expression)
      | _ -> super#expression expression

    method private jsx ~loc callee arguments =
      match callee.pexp_desc with
      | Pexp_ident { txt = Lident tag; _ } -> self#lowercase ~loc tag arguments
      | Pexp_ident { txt = Ldot (path, name); _ } ->
          self#uppercase ~loc path
            (match name with "createElement" -> "make" | other -> other)
            arguments
      | _ -> Location.raise_errorf ~loc "melact: JSX needs a tag or a module name"

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
            match (label, list_items value) with
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
            React.Element
              (Melact_view.View.with_key ([%e key] : string) [%e unwrap ~loc call])])
        key

    method private lowercase ~loc tag arguments =
      let element, key = self#element ~loc tag arguments in
      let html, holes = Markup.render element in
      let path indices = elist ~loc (List.map (eint ~loc) indices) in
      let site_spec indices (site : Markup.site) =
        match site with
        | Attr name ->
            [%expr Melact_view.Template.Attr ([%e path indices], [%e estring ~loc name])]
        | Prop name ->
            [%expr Melact_view.Template.Prop ([%e path indices], [%e estring ~loc name])]
        | Handler event ->
            [%expr Melact_view.Template.Handler ([%e path indices], [%e estring ~loc event])]
        | Ref -> [%expr Melact_view.Template.Ref [%e path indices]]
        | Style -> [%expr Melact_view.Template.Style [%e path indices]]
      in
      let specs, values =
        List.split
          (List.map
             (fun (hole : expression Markup.hole) ->
               match hole with
               | On_element (indices, site, value) -> (site_spec indices site, value)
               | At_position (indices, index, Text_slot, value) ->
                   ( [%expr Melact_view.Template.Text ([%e path indices], [%e eint ~loc index])],
                     value )
               | At_position (indices, index, Child_slot, value) ->
                   ( [%expr Melact_view.Template.Child ([%e path indices], [%e eint ~loc index])],
                     value ))
             holes)
      in
      let template =
        hoist ~loc "template"
          [%expr
            Melact_view.Template.make ~html:[%e estring ~loc html]
              ~holes:[%e pexp_array ~loc specs]]
      in
      let instance =
        match values with
        | [] ->
            hoist ~loc "element"
              [%expr React.Element (Melact_view.View.tpl_instance [%e template] [||])]
        | _ :: _ ->
            [%expr
              React.Element
                (Melact_view.View.tpl_instance [%e template] [%e pexp_array ~loc values])]
      in
      Option.fold ~none:instance
        ~some:(fun key ->
          [%expr
            React.Element
              (Melact_view.View.with_key ([%e key] : string) [%e unwrap ~loc instance])])
        key

    method private element ~loc tag arguments =
      let statics = ref [] and dynamics = ref [] and children = ref [] and key = ref None in
      List.iter
        (fun (label, value) ->
          match label with
          | Nolabel -> ()
          | Labelled "key" -> key := Some (self#expression value)
          | Labelled "children" ->
              children :=
                (match list_items value with
                | Some items -> List.filter_map self#child items
                | None ->
                    [
                      Markup.Slot
                        ( Child_slot,
                          [%expr
                            Melact_view.View.HChild [%e unwrap ~loc (self#expression value)]] );
                    ])
          | Labelled name | Optional name -> (
              let requirement =
                match label with
                | Optional _ -> `Optional
                | Labelled _ | Nolabel -> `Required
              in
              match Dom_props.find name with
              | None ->
                  Location.raise_errorf ~loc:value.pexp_loc "melact: <%s> has no prop %s" tag
                    name
              | Some kind -> (
                  match prop ~loc kind requirement (self#expression value) with
                  | Static (attribute, static) -> statics := (attribute, static) :: !statics
                  | Dynamic (site, hole) -> dynamics := (site, hole) :: !dynamics
                  | Absent -> ())))
        arguments;
      (match (Markup.void tag, !children) with
      | `Void, _ :: _ -> Location.raise_errorf ~loc "melact: <%s> cannot have children" tag
      | `Void, [] | `Container, _ -> ());
      ( {
          Markup.tag;
          statics = List.rev !statics;
          dynamics = List.rev !dynamics;
          children = !children;
        },
        !key )

    method private child item =
      let loc = item.pexp_loc in
      match lowercase item with
      | Some (tag, arguments) -> Some (Markup.Element (fst (self#element ~loc tag arguments)))
      | None -> (
          match (item.pexp_desc, react_text item) with
          | Pexp_ident { txt = Ldot (Lident "React", "null"); _ }, _ -> None
          | _, Some ("string", { pexp_desc = Pexp_constant (Pconst_string (text, _, _)); _ })
            ->
              Some (Markup.Text text)
          | _, Some (("int" | "float"), { pexp_desc = Pexp_constant (Pconst_integer (digits, None) | Pconst_float (digits, None)); _ })
            ->
              Some (Markup.Text digits)
          | _, Some ("int", value) ->
              Some
                (Markup.Slot
                   ( Text_slot,
                     [%expr Melact_view.View.HText (string_of_int ([%e self#expression value] : int))]
                   ))
          | _, Some ("float", value) ->
              Some
                (Markup.Slot
                   ( Text_slot,
                     [%expr
                       Melact_view.View.HText (Js.Float.toString ([%e self#expression value] : float))]
                   ))
          | _, Some (_, value) ->
              Some
                (Markup.Slot
                   (Text_slot, [%expr Melact_view.View.HText ([%e self#expression value] : string)]))
          | _, None ->
              Some
                (Markup.Slot
                   ( Child_slot,
                     [%expr Melact_view.View.HChild [%e unwrap ~loc (self#expression item)]] )))
  end

let structure items = mapper#structure items
let signature items = mapper#signature items

let () =
  Driver.register_transformation "melact" ~impl:structure ~intf:signature
