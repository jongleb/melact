open Ppxlib
open Ast_builder.Default
open Melhole_compiler

let mark = "melact.generalized"

let kept pattern value rest =
  let closed typ =
    let finder =
      object
        inherit [[ `Closed | `Open ]] Ast_traverse.fold as super

        method! core_type typ found =
          match typ.ptyp_desc with Ptyp_any | Ptyp_var _ -> `Open | _ -> super#core_type typ found
      end
    in
    finder#core_type typ `Closed
  in
  let rec fixed argument =
    match argument.ppat_desc with
    | Ppat_constraint (_, typ) -> closed typ
    | Ppat_construct ({ txt = Lident "()"; _ }, None) | Ppat_constant _ -> `Closed
    | Ppat_alias (inner, _) -> fixed inner
    | Ppat_tuple items ->
        List.fold_left
          (fun found item -> match (found, fixed item) with `Closed, `Closed -> `Closed | (`Closed | `Open), _ -> `Open)
          `Closed items
    | _ -> `Open
  in
  let rec generic value =
    match value.pexp_desc with
    | Pexp_function ([], _, Pfunction_cases _) | Pexp_newtype _ -> `Open
    | Pexp_function (params, _, _) ->
        List.fold_left
          (fun found param ->
            match (found, param.pparam_desc) with
            | `Open, _ | `Closed, Pparam_newtype _ -> `Open
            | `Closed, Pparam_val (_, _, argument) -> fixed argument)
          `Closed params
    | Pexp_constraint (inner, typ) -> ( match closed typ with `Closed -> `Closed | `Open -> generic inner)
    | _ -> `Closed
  in
  let named =
    match pattern.ppat_desc with
    | Ppat_var { txt; _ } -> Some (txt, generic value)
    | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, typ) ->
        Some (txt, match closed typ with `Closed -> `Closed | `Open -> generic value)
    | _ -> None
  in
  Option.fold ~none:value
    ~some:(fun (name, parameters) ->
      let slots =
        let finder =
          object (finder)
            inherit [[ `Dom of string | `Prop of string list * string | `Elsewhere of Location.t ] list] Ast_traverse.fold as super

            method! expression expression found =
              match expression.pexp_desc with
              | Pexp_ident { txt = Lident used; _ } when String.equal used name -> `Elsewhere expression.pexp_loc :: found
              | Pexp_apply (({ pexp_desc = Pexp_ident { txt = callee; _ }; _ } as applied), arguments) ->
                  List.fold_left
                    (fun found (label, argument) ->
                      match (label, argument.pexp_desc, callee, Element.without_jsx expression.pexp_attributes) with
                      | Labelled prop, Pexp_ident { txt = Lident used; _ }, Lident _, Some _ when String.equal used name ->
                          `Dom prop :: found
                      | Labelled prop, Pexp_ident { txt = Lident used; _ }, _, (Some _ | None) when String.equal used name ->
                          `Prop ((match Longident.flatten_exn callee with path -> path | exception Invalid_argument _ -> []), prop)
                          :: found
                      | _ -> finder#expression argument found)
                    (finder#expression applied found) arguments
              | _ -> super#expression expression found
          end
        in
        List.sort_uniq compare (finder#expression rest [])
      in
      match (parameters, slots) with
      | `Open, _ :: _ :: _ ->
          let loc = value.pexp_loc in
          {
            value with
            pexp_attributes =
              attribute ~loc ~name:{ txt = mark; loc } ~payload:(PStr [ pstr_eval ~loc (estring ~loc name) [] ])
              :: value.pexp_attributes;
          }
      | (`Open | `Closed), _ -> value)
    named

let instantiated items =
  let marked expression =
    List.find_map
      (fun attribute ->
        match (attribute.attr_name.txt, attribute.attr_payload) with
        | name, PStr [ { pstr_desc = Pstr_eval ({ pexp_desc = Pexp_constant (Pconst_string (generalized, _, _)); _ }, _); _ } ]
          when String.equal name mark ->
            Some generalized
        | _ -> None)
      expression.pexp_attributes
  in
  let unmarked expression =
    {
      expression with
      pexp_attributes = List.filter (fun attribute -> not (String.equal attribute.attr_name.txt mark)) expression.pexp_attributes;
    }
  in
  let typed name = "__melact_typed_" ^ name in
  let substituted name body =
    let shadowing pattern = List.find_opt (String.equal name) (Free.bound pattern) in
    let replacer =
      object (replacer)
        inherit Ast_traverse.map as super

        method! attributes attributes = attributes

        method! case case = Option.fold ~none:(super#case case) ~some:(fun _ -> case) (shadowing case.pc_lhs)

        method! value_binding binding =
          match (binding.pvb_pat.ppat_desc, binding.pvb_expr.pexp_desc) with
          | Ppat_any, Pexp_ident { txt = Lident used; _ } when String.equal used name -> binding
          | _ -> super#value_binding binding

        method! expression expression =
          match expression.pexp_desc with
          | Pexp_ident { txt = Lident used; loc } when String.equal used name ->
              [%expr if false then [%e evar ~loc (typed name)] else Obj.magic [%e expression]]
          | Pexp_let (flag, bindings, rest) -> (
              match (flag, List.filter_map (fun binding -> shadowing binding.pvb_pat) bindings) with
              | _, [] -> super#expression expression
              | Nonrecursive, _ :: _ -> { expression with pexp_desc = Pexp_let (flag, List.map replacer#value_binding bindings, rest) }
              | Recursive, _ :: _ -> expression)
          | Pexp_function (params, _, _) -> (
              match
                List.filter_map
                  (fun param -> match param.pparam_desc with Pparam_val (_, _, pattern) -> shadowing pattern | Pparam_newtype _ -> None)
                  params
              with
              | [] -> super#expression expression
              | _ :: _ -> expression)
          | Pexp_for (pattern, low, high, direction, rest) ->
              Option.fold ~none:(super#expression expression)
                ~some:(fun _ ->
                  { expression with pexp_desc = Pexp_for (pattern, replacer#expression low, replacer#expression high, direction, rest) })
                (shadowing pattern)
          | _ -> super#expression expression
      end
    in
    replacer#expression body
  in
  let found expression =
    let finder =
      object (finder)
        inherit [(string * expression) option] Ast_traverse.fold as super

        method! attributes _ found = found

        method! expression expression found =
          match found with
          | Some _ -> found
          | None -> (
              match (marked expression, expression.pexp_desc) with
              | Some name, _ -> Some (name, unmarked expression)
              | None, Pexp_let (_, _, body) -> finder#expression body found
              | None, _ -> super#expression expression found)
      end
    in
    finder#expression expression None
  in
  let pass =
    object (pass)
      inherit Ast_traverse.map as super

      method! expression expression =
        match expression.pexp_desc with
        | Pexp_let (Nonrecursive, bindings, body) -> (
            match
              List.filter_map
                (fun binding -> Option.map (fun (name, copy) -> (binding.pvb_pat, name, copy)) (found binding.pvb_expr))
                bindings
            with
            | [] -> super#expression expression
            | generalized ->
                let loc = expression.pexp_loc in
                let copies =
                  List.map
                    (fun (pattern, name, copy) ->
                      value_binding ~loc
                        ~pat:
                          (match pattern.ppat_desc with
                          | Ppat_constraint (_, typ) -> ppat_constraint ~loc (pvar ~loc (typed name)) typ
                          | _ -> pvar ~loc (typed name))
                        ~expr:(pass#expression copy))
                    generalized
                in
                pexp_let ~loc Nonrecursive copies
                  (pexp_let ~loc Nonrecursive (List.map pass#value_binding bindings)
                     (List.fold_left (fun body (_, name, _) -> substituted name body) (pass#expression body) generalized)))
        | _ -> super#expression (Option.fold ~none:expression ~some:(fun _ -> unmarked expression) (marked expression))
    end
  in
  pass#structure items
