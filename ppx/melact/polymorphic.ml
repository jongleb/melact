open Ppxlib
open Melhole_compiler

type t = Possibly_polymorphic | Monomorphic

let of_let pattern value rest =
  let occurrences name expression =
    let counter =
      object
        inherit [int] Ast_traverse.fold as super

        method! expression expression found =
          match expression.pexp_desc with
          | Pexp_ident { txt = Lident used; _ } when String.equal used name -> found + 1
          | _ -> super#expression expression found
      end
    in
    counter#expression expression 0
  in
  match (pattern.ppat_desc, value.pexp_desc) with
  | Ppat_var { txt = name; _ }, Pexp_function (params, None, Pfunction_body body) -> (
      let rec unfixed argument =
        match argument.ppat_desc with
        | Ppat_any -> `Unfixed
        | Ppat_var { txt; _ } -> ( match occurrences txt body with 0 -> `Unfixed | _ -> `Fixed)
        | Ppat_alias (inner, { txt; _ }) -> ( match occurrences txt body with 0 -> unfixed inner | _ -> `Fixed)
        | Ppat_tuple items -> (
            match List.exists (fun item -> unfixed item = `Unfixed) items with true -> `Unfixed | false -> `Fixed)
        | _ -> `Fixed
      in
      let free =
        List.exists
          (fun param ->
            match param.pparam_desc with
            | Pparam_val (_, None, argument) -> unfixed argument = `Unfixed
            | Pparam_val (_, Some _, _) | Pparam_newtype _ -> false)
          params
      in
      let slots =
        let finder =
          object (finder)
            inherit [[ `Dom of string | `Prop of string list * string | `Elsewhere of Location.t ] list] Ast_traverse.fold as super

            method! expression expression found =
              match expression.pexp_desc with
              | Pexp_ident { txt = Lident used; _ } when String.equal used name -> `Elsewhere expression.pexp_loc :: found
              | Pexp_apply (({ pexp_desc = Pexp_ident { txt = callee; _ }; _ } as applied), arguments) ->
                  let jsx = Option.is_some (Element.without_jsx expression.pexp_attributes) in
                  List.fold_left
                    (fun found (label, argument) ->
                      match (label, argument.pexp_desc, callee, jsx) with
                      | Labelled prop, Pexp_ident { txt = Lident used; _ }, Lident _, true when String.equal used name ->
                          `Dom prop :: found
                      | Labelled prop, Pexp_ident { txt = Lident used; _ }, _, (true | false) when String.equal used name ->
                          `Prop ((match Longident.flatten_exn callee with path -> path | exception Invalid_argument _ -> []), prop)
                          :: found
                      | _ -> finder#expression argument found)
                    (finder#expression applied found) arguments
              | _ -> super#expression expression found
          end
        in
        List.sort_uniq compare (finder#expression rest [])
      in
      match (free, slots) with
      | true, _ :: _ :: _ -> Possibly_polymorphic
      | (true | false), _ -> Monomorphic)
  | _ -> Monomorphic
