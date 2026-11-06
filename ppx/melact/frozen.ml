open Ppxlib
open Melhole_compiler

type t = Read_only | Possibly_changed

let reading path =
  match path with
  | ("List" | "String" | "Option" | "Int" | "Float" | "Char" | "Bool") :: _
  | "Stdlib" :: ("List" | "String" | "Option" | "Int" | "Float" | "Char" | "Bool") :: _
  | "Belt" :: ("List" | "Option" | "Int" | "Float") :: _
  | "Js" :: ("String" | "Int" | "Float" | "Option") :: _
  | [ "React"; ("string" | "int" | "float" | "array" | "list") ]
  | "ReactDOM" :: "Style" :: _ ->
      Read_only
  | [ ("Array" | "Stdlib"); _ ] | [ "Stdlib"; "Array"; _ ] -> (
      match List.rev path with
      | ( "length" | "get" | "map" | "mapi" | "to_list" | "copy" | "sub" | "append" | "fold_left" | "fold_right"
        | "exists" | "for_all" | "mem" | "memq" | "iter" | "iteri" | "find_opt" | "find_map" | "to_seq" )
        :: _ ->
          Read_only
      | _ -> Possibly_changed)
  | [ "Belt"; "Array"; name ] -> (
      match name with
      | "length" | "size" | "get" | "getExn" | "getUnsafe" | "map" | "mapWithIndex" | "keep" | "keepWithIndex"
      | "keepMap" | "reduce" | "reduceWithIndex" | "some" | "every" | "forEach" | "forEachWithIndex" | "concat"
      | "slice" | "copy" | "reverse" | "zip" | "joinWith" | "getBy" | "getIndexBy" | "partition" | "cmp" | "eq"
      | "flatMap" | "some2" | "every2" ->
          Read_only
      | _ -> Possibly_changed)
  | [ "Js"; "Array"; name ] -> (
      match name with
      | "length" | "map" | "mapi" | "filter" | "filteri" | "reduce" | "reducei" | "some" | "every" | "find"
      | "findi" | "findIndex" | "includes" | "indexOf" | "join" | "slice" | "concat" | "copy" | "forEach"
      | "forEachi" | "toString" ->
          Read_only
      | _ -> Possibly_changed)
  | [ ( "=" | "<>" | "==" | "!=" | "<" | ">" | "<=" | ">=" | "^" | "@" | "fst" | "snd" | "compare" | "not" | "&&"
      | "||" | "max" | "min" | "ignore" | "string_of_int" | "string_of_float" | "string_of_bool" ) ] ->
      Read_only
  | _ -> Possibly_changed

let uses name body =
  let bare expression =
    match expression.pexp_desc with Pexp_ident { txt = Lident found; _ } -> String.equal found name | _ -> false
  in
  let shadows pattern = List.mem name (Free.bound pattern) in
  let called path =
    match (reading path, List.rev path) with
    | Read_only, _ -> `Reading
    | Possibly_changed, last :: _ when String.length last > 3 && String.equal (String.sub last 0 3) "use" -> `Hook
    | Possibly_changed, _ -> `Unknown
  in
  let rec piped expression =
    match expression.pexp_desc with
    | Pexp_apply
        ({ pexp_desc = Pexp_ident { txt = Lident (("|." | "|>") as pipe); _ }; _ }, [ (Nolabel, subject); (Nolabel, step) ]) ->
        let subject = piped subject in
        {
          expression with
          pexp_desc =
            (match (pipe, step.pexp_desc) with
            | "|.", Pexp_apply (callee, arguments) -> Pexp_apply (callee, (Nolabel, subject) :: arguments)
            | _, Pexp_apply (callee, arguments) -> Pexp_apply (callee, arguments @ [ (Nolabel, subject) ])
            | _, _ -> Pexp_apply (step, [ (Nolabel, subject) ]));
        }
    | _ -> expression
  in
  let checker =
    object (checker)
      inherit [t] Ast_traverse.fold as super

      method! expression expression found =
        let within start expressions =
          List.fold_left (fun found expression -> checker#expression expression found) start expressions
        in
        let read start expressions = within start (List.filter (fun expression -> not (bare expression)) expressions) in
        let cases start cases =
          List.fold_left
            (fun found case ->
              match shadows case.pc_lhs with
              | true -> found
              | false -> within found (Option.to_list case.pc_guard @ [ case.pc_rhs ]))
            start cases
        in
        match (found, (piped expression).pexp_desc) with
        | Possibly_changed, _ -> Possibly_changed
        | Read_only, Pexp_ident { txt = Lident found; _ } when String.equal found name -> Possibly_changed
        | Read_only, Pexp_apply (_, arguments) when Option.is_some (Element.without_jsx expression.pexp_attributes) ->
            read found (List.map snd arguments)
        | Read_only, Pexp_apply (({ pexp_desc = Pexp_ident { txt; _ }; _ } as callee), arguments) -> (
            let path = match Longident.flatten_exn txt with path -> path | exception Invalid_argument _ -> [] in
            let values = List.map snd arguments in
            match called path with
            | `Reading -> read found values
            | `Hook ->
                read found
                  (List.concat_map (fun value -> match value.pexp_desc with Pexp_array items -> items | _ -> [ value ]) values)
            | `Unknown -> within found (callee :: values))
        | Read_only, Pexp_match (target, branches) -> cases (read found [ target ]) branches
        | Read_only, Pexp_ifthenelse (test, yes, no) -> within (read found [ test ]) (yes :: Option.to_list no)
        | Read_only, Pexp_field (target, _) -> read found [ target ]
        | Read_only, Pexp_let (flag, bindings, rest) -> (
            let bound = List.exists (fun binding -> shadows binding.pvb_pat) bindings in
            let values = List.map (fun binding -> binding.pvb_expr) bindings in
            match (flag, bound) with
            | Recursive, true -> found
            | (Recursive | Nonrecursive), false -> within found (values @ [ rest ])
            | Nonrecursive, true -> within found values)
        | Read_only, Pexp_function (params, _, function_body) -> (
            let shadowed =
              List.exists
                (fun param ->
                  match param.pparam_desc with Pparam_val (_, _, pattern) -> shadows pattern | Pparam_newtype _ -> false)
                params
            in
            match (shadowed, function_body) with
            | true, _ -> found
            | false, Pfunction_body inner -> within found [ inner ]
            | false, Pfunction_cases (branches, _, _) -> cases found branches)
        | Read_only, _ -> super#expression expression found
    end
  in
  checker#expression body Read_only
