open Ppxlib
open Ast_builder.Default

(** Whether the build asked for hints. *)
type asked = Quiet | Hinting

let asked = ref Quiet

(** The hooks a component calls: how many keep state, and the names of the others. *)
type calls = { cells : int; others : string list }

let () =
  Driver.add_arg "-meltea-hints"
    (Arg.Unit (fun () -> asked := Hinting))
    ~doc:" alert at each component whose only hooks are useState and useReducer: it maps one to one to Meltea"

let () =
  let calls expression =
    let finder =
      object
        inherit [calls] Ast_traverse.fold as super

        method! expression expression found =
          let found = super#expression expression found in
          match expression.pexp_desc with
          | Pexp_ident { txt = Lident name | Ldot (_, name); _ } -> (
              match (Melhole_compiler.Hook_name.of_name name, name) with
              | Plain, _ -> found
              | Hook _, ("useState" | "useReducer") -> { found with cells = found.cells + 1 }
              | Hook _, other -> { found with others = other :: found.others })
          | _ -> found
      end
    in
    finder#expression expression { cells = 0; others = [] }
  in
  let hint binding =
    let loc = binding.pvb_loc in
    match (calls binding.pvb_expr, binding.pvb_pat.ppat_desc) with
    | { cells = 0; _ }, _ | { others = _ :: _; _ }, _ -> None
    | { cells; others = [] }, (Ppat_var { txt = name; _ } | Ppat_constraint ({ ppat_desc = Ppat_var { txt = name; _ }; _ }, _)) ->
        let text =
          Printf.sprintf
            "%s keeps its state in %d useState or useReducer cell%s and calls no other hook: the state is a Meltea \
             model and its setters are messages (docs/migration.md, steps 1 to 3)"
            name cells
            (match cells with 1 -> "" | _ -> "s")
        in
        let here = value_description ~loc ~name:{ txt = "here"; loc } ~type_:[%type: unit] ~prim:[] in
        let alert =
          attribute ~loc ~name:{ txt = "alert"; loc }
            ~payload:(PStr [ pstr_eval ~loc (pexp_apply ~loc (evar ~loc "meltea") [ (Nolabel, estring ~loc text) ]) [] ])
        in
        Some
          [%stri
            let () =
              [%e
                pexp_letmodule ~loc { txt = Some "Melact_hint"; loc }
                  (pmod_constraint ~loc
                     (pmod_structure ~loc [ [%stri let here = ()] ])
                     (pmty_signature ~loc [ psig_value ~loc { here with pval_attributes = [ alert ] } ]))
                  (pexp_ident ~loc { txt = Ldot (Lident "Melact_hint", "here"); loc })]]
    | { cells = _; others = [] }, _ -> None
  in
  let rec hinted items =
    List.concat_map
      (fun item ->
        match item.pstr_desc with
        | Pstr_value (_, bindings) ->
            item
            :: List.filter_map
                 (fun binding ->
                   Option.bind
                     (List.find_opt
                        (fun attribute -> String.equal attribute.attr_name.txt "react.component")
                        binding.pvb_attributes)
                     (fun _ -> hint binding))
                 bindings
        | Pstr_module ({ pmb_expr = { pmod_desc = Pmod_structure inner; _ } as expression; _ } as binding) ->
            [
              {
                item with
                pstr_desc =
                  Pstr_module { binding with pmb_expr = { expression with pmod_desc = Pmod_structure (hinted inner) } };
              };
            ]
        | _ -> [ item ])
      items
  in
  let structure items = match !asked with Quiet -> items | Hinting -> hinted items in
  Driver.register_transformation "melact-meltea-hints" ~instrument:(Driver.Instrument.make structure ~position:Before)
