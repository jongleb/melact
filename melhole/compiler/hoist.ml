open Ppxlib
open Ast_builder.Default

type unused = Dropped | Kept

let counter = ref 0
let lifted = ref []

let hoist ~loc ~unused prefix expression =
  incr counter;
  let name = Printf.sprintf "__melhole_%s_%d" prefix !counter in
  lifted := ([%stri let [%p pvar ~loc name] = [%e expression]], unused) :: !lifted;
  evar ~loc name

let declare ~loc prefix declaration =
  incr counter;
  let name = Printf.sprintf "__melhole_%s_%d" prefix !counter in
  let declared = declaration name in
  lifted :=
    ( pstr_type ~loc Recursive
        [
          {
            declared with
            ptype_attributes =
              attribute ~loc ~name:{ txt = "ocaml.warning"; loc } ~payload:(PStr [ pstr_eval ~loc (estring ~loc "-34-69") [] ])
              :: declared.ptype_attributes;
          };
        ],
      Kept )
    :: !lifted;
  name

let structure map items =
  let module Names = Set.Make (String) in
  let ignoring name expression =
    match expression.pexp_desc with
    | Pexp_let
        ( Nonrecursive,
          [ { pvb_pat = { ppat_desc = Ppat_any; _ }; pvb_expr = { pexp_desc = Pexp_ident { txt = Lident used; _ }; _ }; _ } ],
          rest )
      when String.equal used name ->
        Some rest
    | _ -> None
  in
  let pruned =
    object
      inherit Ast_traverse.map as super

      method! expression expression =
        let expression = super#expression expression in
        match expression.pexp_desc with
        | Pexp_let
            ( Nonrecursive,
              [
                {
                  pvb_pat = { ppat_desc = Ppat_var { txt = name; _ }; _ };
                  pvb_expr = { pexp_desc = Pexp_function _ | Pexp_constraint ({ pexp_desc = Pexp_function _; _ }, _); _ };
                  _;
                };
              ],
              body ) -> (
            let uses =
              object
                inherit [int * int] Ast_traverse.fold as super

                method! expression expression (all, ignored) =
                  match (expression.pexp_desc, ignoring name expression) with
                  | Pexp_ident { txt = Lident used; _ }, _ when String.equal used name -> (all + 1, ignored)
                  | Pexp_letop { let_; ands; _ }, _
                    when List.exists (fun (operator : binding_op) -> String.equal operator.pbop_op.txt name) (let_ :: ands) ->
                      super#expression expression (all + 1, ignored)
                  | _, Some _ -> super#expression expression (all, ignored + 1)
                  | _, None -> super#expression expression (all, ignored)
              end
            in
            match uses#expression body (0, 0) with
            | all, ignored when all = ignored && ignored > 0 ->
                let unignored =
                  object (self)
                    inherit Ast_traverse.map as super

                    method! expression expression =
                      match ignoring name expression with
                      | Some rest -> self#expression rest
                      | None -> super#expression expression
                  end
                in
                unignored#expression body
            | _, _ -> expression)
        | _ -> expression
    end
  in
  let referenced =
    object
      inherit [Names.t] Ast_traverse.fold as super

      method! longident longident found = super#longident longident (Names.add (Longident.last_exn longident) found)
    end
  in
  let mapped =
    List.map
      (fun item ->
        let saved = !lifted in
        lifted := [];
        let item = pruned#structure_item (map item) in
        let before = List.rev !lifted in
        lifted := saved;
        (before, item))
      items
  in
  fst
    (List.fold_right
       (fun (before, item) (kept, used) ->
         let before, used =
           List.fold_right
             (fun (hoisted, unused) (kept, used) ->
               match (unused, hoisted.pstr_desc) with
               | Dropped, Pstr_value (_, [ { pvb_pat = { ppat_desc = Ppat_var { txt = name; _ }; _ }; _ } ])
                 when not (Names.mem name used) ->
                   (kept, used)
               | (Dropped | Kept), _ -> (hoisted :: kept, referenced#structure_item hoisted used))
             before ([], used)
         in
         (before @ (item :: kept), used))
       mapped
       ([], List.fold_left (fun used (_, item) -> referenced#structure_item item used) Names.empty mapped))
