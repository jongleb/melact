open Ppxlib
open Ast_builder.Default

type t = { labels : string list; traced : Location.t list; literals : Location.t list; misses : Location.t list; checked : Location.t list }

let name = "melact.cloned"

(** Where an element that reaches a clone comes from. *)
type origin =
  | Label of string  (** The elements a component is given as this label. *)
  | Literal of Location.t  (** The JSX literal at this location. *)
  | Blank  (** [React.null], which [Children.map] and [toArray] skip, given where a caller's elements are checked. *)

let rec bound pattern =
  match pattern.ppat_desc with
  | Ppat_var { txt; _ } -> Some txt
  | Ppat_constraint (inner, _) | Ppat_alias (inner, _) -> bound inner
  | _ -> None

let reached ~of_component sources expression =
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
    let bind variable origins = List.map (fun origin -> (variable, origin)) origins in
    let rec derived_in sources expression =
      let expression = piped expression in
      match (Melhole_compiler.Element.without_jsx expression.pexp_attributes, expression.pexp_desc) with
      | Some _, _ -> [ Literal expression.pexp_loc ]
      | None, Pexp_ident { txt = Lident variable; _ } ->
          List.filter_map (fun (name, origin) -> match String.equal name variable with true -> Some origin | false -> None) sources
      | None, Pexp_let (_, bindings, inner) ->
          derived_in
            (List.concat_map
               (fun binding ->
                 Option.fold ~none:[] ~some:(fun variable -> bind variable (derived_in sources binding.pvb_expr)) (bound binding.pvb_pat))
               bindings
            @ sources)
            inner
      | None, (Pexp_constraint (inner, _) | Pexp_sequence (_, inner)) -> derived_in sources inner
      | None, Pexp_apply (_, arguments) ->
          List.concat_map (fun (_, argument) -> match argument.pexp_desc with Pexp_function _ -> [] | _ -> derived_in sources argument) arguments
      | None, Pexp_match (_, cases) -> List.concat_map (fun case -> derived_in sources case.pc_rhs) cases
      | None, Pexp_ifthenelse (_, yes, no) -> derived_in sources yes @ Option.fold ~none:[] ~some:(derived_in sources) no
      | None, _ -> []
    in
    let derived expression = derived_in sources expression in
    let reach item = match derived item with [] -> walk sources item | origins -> found := origins @ !found in
    match expression.pexp_desc with
    | Pexp_let (_, bindings, rest) ->
        List.iter (fun binding -> walk sources binding.pvb_expr) bindings;
        walk
          (List.concat_map
             (fun binding -> Option.fold ~none:[] ~some:(fun variable -> bind variable (derived binding.pvb_expr)) (bound binding.pvb_pat))
             bindings
          @ sources)
          rest
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (Lident "React", "cloneElement"); _ }; _ }, (_, element) :: rest) ->
        reach element;
        List.iter (fun (_, argument) -> walk sources argument) rest
    | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (path, "createElement"); _ }; _ }, arguments)
      when Option.is_some (Melhole_compiler.Element.without_jsx expression.pexp_attributes) ->
        let cloned = of_component (Ldot (path, "makeProps")) in
        List.iter
          (fun (label, value) ->
            match label with
            | (Labelled given | Optional given) when List.mem given cloned ->
                List.iter reach (Option.value ~default:[ value ] (Melhole_compiler.Element.list_items value))
            | Labelled _ | Optional _ | Nolabel -> walk sources value)
          arguments
    | Pexp_apply (callee, arguments) ->
        let origins = List.concat_map (fun (_, argument) -> match argument.pexp_desc with Pexp_function _ -> [] | _ -> derived argument) arguments in
        let rec parameters lambda =
          match lambda.pexp_desc with
          | Pexp_function (given, _, body) ->
              List.filter_map
                (fun parameter -> match parameter.pparam_desc with Pparam_val (_, _, pattern) -> bound pattern | Pparam_newtype _ -> None)
                given
              @ (match body with Pfunction_body inner -> parameters inner | Pfunction_cases _ -> [])
          | _ -> []
        in
        walk sources callee;
        List.iter
          (fun (_, argument) ->
            match (argument.pexp_desc, origins) with
            | Pexp_function _, _ :: _ -> walk (List.concat_map (fun variable -> bind variable origins) (parameters argument) @ sources) argument
            | _, ([] | _ :: _) -> walk sources argument)
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
  walk sources expression;
  !found

let candidates ~of_component expression =
  let rec split expression =
    match expression.pexp_desc with
    | Pexp_function (given, _, Pfunction_body inner) ->
        let more, body = split inner in
        ( List.filter_map
            (fun parameter ->
              match parameter.pparam_desc with
              | Pparam_val ((Labelled label | Optional label), _, pattern) -> Option.map (fun variable -> (variable, Label label)) (bound pattern)
              | Pparam_val (Nolabel, _, _) | Pparam_newtype _ -> None)
            given
          @ more,
          body )
    | Pexp_constraint (inner, _) -> split inner
    | _ -> ([], expression)
  in
  let parameters, body = split expression in
  List.sort_uniq String.compare
    (List.filter_map (fun origin -> match origin with Label label -> Some label | Literal _ | Blank -> None) (reached ~of_component parameters body))

let literals ~of_component bindings =
  List.concat_map
    (fun binding ->
      List.filter_map (fun origin -> match origin with Literal at -> Some at | Label _ | Blank -> None) (reached ~of_component [] binding.pvb_expr))
    bindings

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

let traced ~known ~seeded (expression : Ocaml_common.Typedtree.expression) =
  let open Ocaml_common in
  let found = ref [] and calls = ref [] and misses = ref [] and checked = ref [] in
  let value_name env path =
    List.fold_left
      (fun name (packed, plain) ->
        match String.starts_with ~prefix:packed name with
        | true -> plain ^ String.sub name (String.length packed) (String.length name - String.length packed)
        | false -> name)
      (match Env.normalize_value_path None env path with exception _ -> Path.name path | normal -> Path.name normal)
      [ ("Stdlib__", "Stdlib."); ("Belt__Belt_", "Belt_"); ("Js__Js_", "Js_"); ("Melact_runtime__", "Melact_runtime.") ]
  in
  let elements sources (pattern : Typedtree.pattern) origins =
    List.concat_map
      (fun (ident, _, type_expr, _) ->
        match element_kind pattern.pat_env type_expr with
        | `Element | `Elements -> List.map (fun origin -> (ident, origin)) origins
        | `Other -> [])
      (Typedtree.pat_bound_idents_full pattern)
    @ sources
  in
  let given arguments = List.filter_map (fun (label, argument) -> match argument with Typedtree.Arg value -> Some (label, value) | Typedtree.Omitted () -> None) arguments in
  let rec flat (expression : Typedtree.expression) =
    match expression.exp_desc with
    | Texp_apply ({ exp_desc = Texp_apply _; _ } as inner, outer) -> (
        match (flat inner).Typedtree.exp_desc with
        | Texp_apply (callee, first) -> { expression with Typedtree.exp_desc = Texp_apply (callee, first @ outer) }
        | _ -> expression)
    | _ -> expression
  in
  let rec memoized (expression : Typedtree.expression) =
    match expression.exp_desc with
    | Texp_let (_, _, body) -> memoized body
    | Texp_match (_, cases, _, _) ->
        List.find_map
          (fun (case : Typedtree.computation Typedtree.case) ->
            match case.c_rhs.exp_desc with
            | Texp_apply ({ exp_desc = Texp_ident (path, _, _); exp_env; _ }, arguments)
              when String.equal (value_name exp_env path) "Melact_runtime.Memo.store" -> (
                match given arguments with [ _; _; _; (_, value) ] -> Some value | _ -> None)
            | _ -> None)
          cases
    | _ -> None
  in
  let rec walk sources (expression : Typedtree.expression) =
    let rec derived_in ~blank sources (expression : Typedtree.expression) =
      let derived = derived_in ~blank sources in
      let expression = flat expression in
      let every branches =
        List.fold_left (fun all branch -> Option.bind all (fun all -> Option.map (fun more -> all @ more) (derived branch))) (Some []) branches
      in
      match expression.exp_desc with
      | Texp_ident (Path.Pident ident, _, _) -> (
          match List.filter_map (fun (bound, origin) -> match Ident.same bound ident with true -> Some origin | false -> None) sources with
          | [] -> None
          | origins -> Some origins)
      | Texp_ident (path, _, _) when String.equal (value_name expression.exp_env path) "React.null" -> (
          match blank with `Clonable -> Some [ Blank ] | `Unknown -> None)
      | Texp_let (_, bindings, body) ->
          derived_in ~blank
            (List.fold_left
               (fun inner (binding : Typedtree.value_binding) ->
                 Option.fold ~none:inner ~some:(elements inner binding.vb_pat) (derived binding.vb_expr))
               sources bindings)
            body
      | Texp_sequence (_, body) -> derived body
      | Texp_ifthenelse (_, yes, Some no) -> every [ yes; no ]
      | Texp_match _ when Option.is_some (memoized expression) -> Option.bind (memoized expression) derived
      | Texp_match (_, cases, _, _) -> every (List.map (fun (case : Typedtree.computation Typedtree.case) -> case.c_rhs) cases)
      | Texp_apply ({ exp_desc = Texp_ident (path, _, _); exp_env; _ }, arguments) -> (
          match (value_name exp_env path, List.map snd (given arguments)) with
          | "React.clonable", _ -> Some [ Literal expression.exp_loc ]
          | ( "React.Children.only" | "React.Children.toArray" | "Stdlib.Array.get" | "Stdlib.Array.unsafe_get" | "Stdlib.List.hd" | "Stdlib.List.nth"
            | "Stdlib.Option.get" | "Belt_Array.getExn" | "Belt_Array.getUnsafe" | "Belt_List.headExn" | "Belt_List.getExn" | "Belt_Array.keep"
            | "Belt_Array.keepWithIndex" | "Belt_Array.slice" | "Belt_Array.sliceToEnd" | "Belt_Array.reverse" | "Belt_List.keep" | "Belt_List.toArray"
            | "Belt_List.fromArray" | "Belt_List.reverse" | "Js_array.copy" | "Stdlib.Array.of_list" | "Stdlib.Array.to_list" | "Stdlib.Array.sub" | "Stdlib.Array.copy" | "Stdlib.List.rev"
            | "Stdlib.List.tl" ),
            given :: _ ->
              derived given
          | ("Stdlib.List.filter" | "Stdlib.List.filteri" | "Js_array.filter" | "Js_array.filteri" | "Js_array.slice"), (_ :: _ as all) ->
              derived (List.nth all (List.length all - 1))
          | ("Stdlib.|>" | "|."), [ given; _ ] | "React.cloneElement", given :: _ -> derived given
          | _ -> None)
      | _ -> None
    in
    let derived expression = derived_in ~blank:`Unknown sources expression in
    let inside (expression : Typedtree.expression) =
      let iterator = { Tast_iterator.default_iterator with expr = (fun _ inner -> walk sources inner) } in
      Tast_iterator.default_iterator.expr iterator expression
    in
    let expression = flat expression in
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
              | Some origins, (Some value, _) -> elements sources value origins
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
              ~some:(fun origins ->
                found := origins @ !found;
                calls := expression.exp_loc :: !calls)
              (derived element);
            List.iter (fun (_, argument) -> walk sources argument) rest
        | _ ->
            let source = List.find_map (fun (_, argument) -> derived argument) arguments in
            List.iter
              (fun (label, (argument : Typedtree.expression)) ->
                match label with
                | (Asttypes.Labelled forwarded | Asttypes.Optional forwarded) when List.mem forwarded cloned ->
                    List.iter
                      (fun (item : Typedtree.expression) ->
                        Option.fold
                          ~none:(misses := item.exp_loc :: !misses)
                          ~some:(fun origins ->
                            checked := item.exp_loc :: !checked;
                            found := origins @ !found)
                          (derived_in ~blank:`Clonable sources item))
                      (match argument.exp_desc with
                      | Texp_array (_, items) | Texp_apply (_, [ (_, Typedtree.Arg { exp_desc = Texp_array (_, items); _ }) ]) -> items
                      | _ -> [ argument ]);
                    walk sources argument
                | _ -> (
                    match (source, argument.exp_desc) with
                    | Some origins, Texp_function _ ->
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
                               | Tparam_pat pattern | Tparam_optional_default (pattern, _) -> elements sources pattern origins)
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
               | (Asttypes.Labelled label | Asttypes.Optional label), (Tparam_pat pattern | Tparam_optional_default (pattern, _)) ->
                   elements sources pattern [ Label label ]
               | Asttypes.Nolabel, _ -> sources)
             sources given)
          body
    | _ -> walk sources expression
  in
  (match seeded with `Labels -> parameters [] expression | `Unseeded -> walk [] expression);
  {
    labels = List.sort_uniq String.compare (List.filter_map (fun origin -> match origin with Label label -> Some label | Literal _ | Blank -> None) !found);
    traced = !calls;
    literals = List.filter_map (fun origin -> match origin with Literal at -> Some at | Label _ | Blank -> None) !found;
    misses = !misses;
    checked = !checked;
  }

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
                    found := (binding.vb_loc, binding.vb_pat.pat_loc, traced ~known:(labels_in !found) ~seeded:`Labels binding.vb_expr) :: !found
                | _ -> ());
                Ocaml_common.Tast_iterator.default_iterator.value_binding self binding);
          }
        in
        let typed = Melhole_typed.File.typed file in
        iterator.structure iterator typed;
        let loose = ref [] in
        let everywhere =
          {
            Ocaml_common.Tast_iterator.default_iterator with
            expr = (fun _ expression -> loose := traced ~known:(labels_in !found) ~seeded:`Unseeded expression :: !loose);
          }
        in
        everywhere.structure everywhere typed;
        let scans = List.map (fun (_, _, scan) -> scan) !found @ !loose in
        let whole =
          {
            labels = List.sort_uniq String.compare (List.concat_map (fun scan -> scan.labels) scans);
            traced = List.concat_map (fun scan -> scan.traced) scans;
            literals = List.concat_map (fun scan -> scan.literals) scans;
            misses =
              (let checked = List.concat_map (fun scan -> scan.checked) scans in
               List.sort_uniq Location.compare
                 (List.filter
                    (fun at -> not (List.exists (fun seen -> Location.compare seen at = 0) checked))
                    (List.concat_map (fun scan -> scan.misses) scans)));
            checked = List.concat_map (fun scan -> scan.checked) scans;
          }
        in
        cached := Some (file, (!found, whole));
        (!found, whole)

let in_file file = List.map (fun (at, _, scan) -> (at, scan)) (fst (scanned file))

let whole file = snd (scanned file)

let known file description = labels_in (fst (scanned file)) description

let flagged file structure =
  let rec mapper misses =
    object
      inherit Ast_traverse.map as super

      method! expression expression =
        Option.fold ~none:(super#expression expression)
          ~some:(fun at ->
            let loc = expression.pexp_loc in
            [%expr React.unclonable [%e (mapper (List.filter (fun other -> Location.compare other at <> 0) misses))#expression expression]])
          (List.find_opt (fun at -> Location.compare at expression.pexp_loc = 0) misses)
    end
  in
  (mapper (whole file).misses)#structure structure
