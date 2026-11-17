open Ppxlib
open Ast_builder.Default

type t = { labels : string list; traced : Location.t list }

let name = "melact.cloned"

let candidates ~of_component expression =
  let rec bound pattern =
    match pattern.ppat_desc with
    | Ppat_var { txt; _ } -> Some txt
    | Ppat_constraint (inner, _) | Ppat_alias (inner, _) -> bound inner
    | _ -> None
  in
  let rec split expression =
    match expression.pexp_desc with
    | Pexp_function (given, _, Pfunction_body inner) ->
        let more, body = split inner in
        ( List.filter_map
            (fun parameter ->
              match parameter.pparam_desc with
              | Pparam_val ((Labelled label | Optional label), _, pattern) -> Option.map (fun variable -> (variable, label)) (bound pattern)
              | Pparam_val (Nolabel, _, _) | Pparam_newtype _ -> None)
            given
          @ more,
          body )
    | Pexp_constraint (inner, _) -> split inner
    | _ -> ([], expression)
  in
  let found = ref [] in
  let piped expression =
    match expression.pexp_desc with
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident "|."; _ }; _ }, [ (_, subject); (_, { pexp_desc = Pexp_apply (callee, given); _ }) ]) ->
        { expression with pexp_desc = Pexp_apply (callee, (Nolabel, subject) :: given) }
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident "|>"; _ }; _ }, [ (_, subject); (_, { pexp_desc = Pexp_apply (callee, given); _ }) ]) ->
        { expression with pexp_desc = Pexp_apply (callee, given @ [ (Nolabel, subject) ]) }
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident ("|." | "|>"); _ }; _ }, [ (_, subject); (_, callee) ]) ->
        { expression with pexp_desc = Pexp_apply (callee, [ (Nolabel, subject) ]) }
    | _ -> expression
  in
  let rec walk sources expression =
    let expression = piped expression in
    let rec derived expression =
      let expression = piped expression in
      match expression.pexp_desc with
      | Pexp_ident { txt = Lident variable; _ } -> List.assoc_opt variable sources
      | Pexp_constraint (inner, _) -> derived inner
      | Pexp_apply
          ({ pexp_desc = Pexp_ident { txt = Ldot (Ldot (Lident "React", "Children"), ("only" | "toArray")); _ }; _ }, [ (_, inner) ]) ->
          derived inner
      | _ -> None
    in
    let over items row =
      walk sources items;
      match (derived items, row.pexp_desc) with
      | Some label, Pexp_function ({ pparam_desc = Pparam_val (_, _, pattern); _ } :: _, _, _) ->
          walk (Option.fold ~none:sources ~some:(fun variable -> (variable, label) :: sources) (bound pattern)) row
      | (Some _ | None), _ -> walk sources row
    in
    match expression.pexp_desc with
    | Pexp_let (_, bindings, rest) ->
        List.iter (fun binding -> walk sources binding.pvb_expr) bindings;
        walk
          (List.filter_map
             (fun binding -> Option.bind (bound binding.pvb_pat) (fun variable -> Option.map (fun label -> (variable, label)) (derived binding.pvb_expr)))
             bindings
          @ sources)
          rest
    | Pexp_apply
        ( {
            pexp_desc =
              Pexp_ident
                {
                  txt =
                    Ldot
                      ( (Ldot (Lident "React", "Children") | Ldot (Lident "Belt", "Array")),
                        ("map" | "mapWithIndex" | "forEach" | "forEachWithIndex") );
                  _;
                };
            _;
          },
          [ (_, items); (_, row) ] ) ->
        over items row
    | Pexp_apply
        ( { pexp_desc = Pexp_ident { txt = Ldot ((Lident ("Array" | "List") | Ldot (Lident "Js", "Array")), ("map" | "mapi" | "iter" | "iteri")); _ }; _ },
          [ (_, row); (_, items) ] ) ->
        over items row
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (Lident "React", "cloneElement"); _ }; _ }, (_, element) :: rest) ->
        Option.fold ~none:(walk sources element)
          ~some:(fun label -> found := label :: !found)
          (derived element);
        List.iter (fun (_, argument) -> walk sources argument) rest
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (path, "createElement"); _ }; _ }, arguments)
      when Option.is_some (Melhole_compiler.Element.without_jsx expression.pexp_attributes) ->
        let cloned = of_component (Ldot (path, "makeProps")) in
        List.iter
          (fun (label, value) ->
            match label with
            | (Labelled given | Optional given) when List.mem given cloned ->
                List.iter
                  (fun item -> Option.fold ~none:(walk sources item) ~some:(fun label -> found := label :: !found) (derived item))
                  (Option.value ~default:[ value ] (Melhole_compiler.Element.list_items value))
            | Labelled _ | Optional _ | Nolabel -> walk sources value)
          arguments
    | _ ->
        let first = ref `First in
        (object
           inherit Ast_traverse.iter as super

           method! expression inner =
             match !first with
             | `First ->
                 first := `Inside;
                 super#expression inner
             | `Inside -> walk sources inner
        end)
          #expression
          expression
  in
  let parameters, body = split expression in
  walk parameters body;
  List.sort_uniq String.compare !found

let element_kind env type_expr =
  let rec kind answer =
    match Melhole_typed.Answer.view answer with
    | Melhole_typed.Answer.Named { path = "React.element"; arguments = []; _ } -> `Element
    | Melhole_typed.Answer.Named { path = "array" | "list"; arguments = [ item ]; _ } -> (
        match kind item with `Element | `Elements -> `Elements | `Other -> `Other)
    | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Function _ | Melhole_typed.Answer.Js_object _ | Melhole_typed.Answer.Object _
    | Melhole_typed.Answer.Other ->
        `Other
  in
  kind (Melhole_typed.Answer.make env type_expr)

let of_attributes (attributes : Ocaml_common.Typedtree.attributes) =
  let rec strings expression =
    match expression.pexp_desc with
    | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> Some []
    | Pexp_construct ({ txt = Lident "::"; _ }, Some { pexp_desc = Pexp_tuple [ { pexp_desc = Pexp_constant (Pconst_string (label, _, _)); _ }; rest ]; _ }) ->
        Option.map (List.cons label) (strings rest)
    | _ -> None
  in
  List.find_map
    (fun (attribute : Ocaml_common.Typedtree.attribute) ->
      match (attribute.attr_name.txt, attribute.attr_payload) with
      | found, PStr payload when String.equal found name -> (
          match Ppxlib_ast.Selected_ast.of_ocaml Structure payload with
          | [ { pstr_desc = Pstr_eval (labels, _); _ } ] -> strings labels
          | _ -> None
          | exception _ -> None)
      | _ -> None)
    attributes

let traced ~known (expression : Ocaml_common.Typedtree.expression) =
  let open Ocaml_common in
  let found = ref [] and calls = ref [] in
  let value_name env path = match Env.normalize_value_path None env path with exception _ -> Path.name path | normal -> Path.name normal in
  let elements sources (pattern : Typedtree.pattern) label =
    List.filter_map
      (fun (ident, _, type_expr, _) ->
        match element_kind pattern.pat_env type_expr with `Element | `Elements -> Some (ident, label) | `Other -> None)
      (Typedtree.pat_bound_idents_full pattern)
    @ sources
  in
  let rec walk sources (expression : Typedtree.expression) =
    let rec derived (expression : Typedtree.expression) =
      match expression.exp_desc with
      | Texp_ident (Path.Pident ident, _, _) -> List.assoc_opt ident sources
      | Texp_apply ({ exp_desc = Texp_ident (path, _, _); exp_env; _ }, arguments) -> (
          match (value_name exp_env path, List.filter_map (fun (_, argument) -> match argument with Typedtree.Arg given -> Some given | Typedtree.Omitted () -> None) arguments) with
          | ("React.Children.only" | "React.Children.toArray" | "Stdlib.Array.get" | "Stdlib.Array.unsafe_get" | "Stdlib.List.hd" | "Stdlib.List.nth"
            | "Stdlib.Option.get" | "Belt_Array.getExn" | "Belt_Array.getUnsafe" | "Belt_List.headExn" | "Belt_List.getExn"), given :: _ ->
              derived given
          | ("Stdlib.|>" | "|."), [ given; _ ] -> derived given
          | _ -> None)
      | _ -> None
    in
    let inside (expression : Typedtree.expression) =
      let iterator = { Tast_iterator.default_iterator with expr = (fun _ inner -> walk sources inner) } in
      Tast_iterator.default_iterator.expr iterator expression
    in
    let given arguments = List.filter_map (fun (label, argument) -> match argument with Typedtree.Arg value -> Some (label, value) | Typedtree.Omitted () -> None) arguments in
    let expression =
      let rec flat (expression : Typedtree.expression) =
        match expression.Typedtree.exp_desc with
        | Texp_apply ({ exp_desc = Texp_apply _; _ } as inner, outer) -> (
            match (flat inner).Typedtree.exp_desc with
            | Texp_apply (callee, first) -> { expression with Typedtree.exp_desc = Texp_apply (callee, first @ outer) }
            | _ -> expression)
        | _ -> expression
      in
      flat expression
    in
    match expression.exp_desc with
    | Texp_let (_, bindings, body) ->
        List.iter (fun (binding : Typedtree.value_binding) -> walk sources binding.vb_expr) bindings;
        walk
          (List.fold_left
             (fun sources (binding : Typedtree.value_binding) ->
               Option.fold ~none:sources ~some:(elements sources binding.vb_pat) (derived binding.vb_expr))
             sources bindings)
          body
    | Texp_match (scrutinee, cases, _, _) ->
        walk sources scrutinee;
        List.iter
          (fun (case : Typedtree.computation Typedtree.case) ->
            let sources =
              match (derived scrutinee, Typedtree.split_pattern case.c_lhs) with
              | Some label, (Some value, _) -> elements sources value label
              | Some _, (None, _) | None, _ -> sources
            in
            Option.iter (walk sources) case.c_guard;
            walk sources case.c_rhs)
          cases
    | Texp_apply (({ exp_desc = Texp_ident (path, _, _); exp_env; _ } as callee), arguments) -> (
        let callee, arguments =
          match (value_name exp_env path, given arguments) with
          | ("Stdlib.|>" | "|."), [ (_, subject); (_, { exp_desc = Texp_apply (inner, more); _ }) ] -> (inner, given more @ [ (Asttypes.Nolabel, subject) ])
          | _, plain -> (callee, plain)
        in
        let name, cloned =
          match callee.exp_desc with Texp_ident (path, _, description) -> (value_name callee.exp_env path, known description) | _ -> ("", [])
        in
        match (name, arguments) with
        | "React.cloneElement", (_, element) :: rest ->
            Option.fold ~none:(walk sources element)
              ~some:(fun label ->
                found := label :: !found;
                calls := expression.exp_loc :: !calls)
              (derived element);
            List.iter (fun (_, argument) -> walk sources argument) rest
        | _ ->
            let source = List.find_map (fun (_, argument) -> derived argument) arguments in
            List.iter
              (fun (label, (argument : Typedtree.expression)) ->
                let items =
                  match argument.exp_desc with
                  | Texp_array (_, items) -> argument :: items
                  | Texp_apply (_, [ (_, Typedtree.Arg { exp_desc = Texp_array (_, items); _ }) ]) -> argument :: items
                  | _ -> [ argument ]
                in
                match (label, List.find_map derived items) with
                | (Asttypes.Labelled forwarded | Asttypes.Optional forwarded), Some label when List.mem forwarded cloned -> found := label :: !found
                | _ -> (
                    match (source, argument.exp_desc) with
                    | Some label, Texp_function _ ->
                        let rec parameters (lambda : Typedtree.expression) =
                          match lambda.exp_desc with
                          | Texp_function (given, Tfunction_body body) -> given @ parameters body
                          | Texp_function (given, Tfunction_cases _) -> given
                          | _ -> []
                        in
                        walk
                          (List.fold_left
                             (fun sources (parameter : Typedtree.function_param) ->
                               match parameter.fp_kind with
                               | Tparam_pat pattern | Tparam_optional_default (pattern, _) -> elements sources pattern label)
                             sources (parameters argument))
                          argument
                    | (Some _ | None), _ -> walk sources argument))
              arguments)
    | _ -> inside expression
  in
  let rec parameters sources (expression : Typedtree.expression) =
    match expression.exp_desc with
    | Texp_function (given, Tfunction_body body) ->
        parameters
          (List.fold_left
             (fun sources (parameter : Typedtree.function_param) ->
               match (parameter.fp_arg_label, parameter.fp_kind) with
               | (Asttypes.Labelled label | Asttypes.Optional label), (Tparam_pat pattern | Tparam_optional_default (pattern, _)) -> elements sources pattern label
               | Asttypes.Nolabel, _ -> sources)
             sources given)
          body
    | _ -> walk sources expression
  in
  parameters [] expression;
  { labels = List.sort_uniq String.compare !found; traced = !calls }

let fact ~loc labels = attribute ~loc ~name:{ loc; txt = name } ~payload:(PStr [ pstr_eval ~loc (elist ~loc (List.map (estring ~loc) labels)) [] ])

let environment = lazy (match Ocaml_common.Compmisc.initial_env () with environment -> Some environment | exception _ -> None)

let imported path =
  Option.value ~default:[]
    (Option.bind (Ocaml_common.Longident.unflatten (Longident.flatten_exn path)) (fun lid ->
         Option.bind (Lazy.force environment) (fun environment ->
             match Ocaml_common.Env.lookup_value ~use:false ~loc:Ocaml_common.Location.none lid environment with
             | exception _ -> None
             | _, description -> of_attributes description.val_attributes)))

let components = ref []

let labels_in found (description : Ocaml_common.Types.value_description) =
  Option.value ~default:[]
    (Option.fold
       ~none:(List.find_map (fun (_, at, scan) -> match Location.compare at description.val_loc with 0 -> Some scan.labels | _ -> None) found)
       ~some:Option.some (of_attributes description.val_attributes))

let scanned =
  let cached = ref None in
  fun file ->
    match !cached with
    | Some (seen, found) when seen == file -> found
    | Some _ | None ->
        let found = ref [] in
        let iterator =
          {
            Ocaml_common.Tast_iterator.default_iterator with
            value_binding =
              (fun self (binding : Ocaml_common.Typedtree.value_binding) ->
                (match binding.vb_pat.pat_desc with
                | Ocaml_common.Typedtree.Tpat_var (ident, _, _)
                  when List.exists
                         (fun (at, props) -> Location.compare at binding.vb_loc = 0 && String.equal props (Ocaml_common.Ident.name ident))
                         !components ->
                    found := (binding.vb_loc, binding.vb_pat.pat_loc, traced ~known:(labels_in !found) binding.vb_expr) :: !found
                | _ -> ());
                Ocaml_common.Tast_iterator.default_iterator.value_binding self binding);
          }
        in
        iterator.structure iterator (Melhole_typed.File.typed file);
        cached := Some (file, !found);
        !found

let in_file file = List.map (fun (at, _, scan) -> (at, scan)) (scanned file)

let known file description = labels_in (scanned file) description
