open Ppxlib
open Ast_builder.Default

let lazy_props = "melact.lazy_props"

let structure items =
  let imported =
    (object
       inherit [longident list] Ast_traverse.fold as super

       method! expression expression found =
         match expression.pexp_desc with
         | Pexp_apply
             ( { pexp_desc = Pexp_ident { txt = Ldot (Lident "Js", "import"); _ }; _ },
               [ (Nolabel, { pexp_desc = Pexp_ident { txt = Ldot (path, _); _ }; _ }) ] ) ->
             path :: found
         | _ -> super#expression expression found
    end)
      #structure items []
  in
  let wrapped =
    object
      inherit Ast_traverse.map as super

      method! expression expression =
        match expression.pexp_desc with
        | Pexp_apply (({ pexp_desc = Pexp_ident { txt = Ldot (path, name); _ }; _ } as callee), arguments)
          when List.mem path imported && String.ends_with ~suffix:"Props" name ->
            let loc = expression.pexp_loc in
            let fields =
              List.filter_map
                (fun (label, _) -> match label with Labelled name -> Some (`Labelled, name) | Optional name -> Some (`Optional, name) | Nolabel -> None)
                arguments
            in
            let variable index = ptyp_var ~loc (Printf.sprintf "melact_%d" index) in
            let shape =
              ptyp_object ~loc
                (List.mapi
                   (fun index (kind, name) ->
                     otag ~loc { loc; txt = name }
                       (match kind with `Labelled -> variable index | `Optional -> [%type: [%t variable index] option]))
                   fields)
                Closed
            in
            let made =
              List.fold_right
                (fun (index, (kind, name)) result ->
                  ptyp_arrow ~loc (match kind with `Labelled -> Labelled name | `Optional -> Optional name) (variable index) result)
                (List.mapi (fun index field -> (index, field)) fields)
                [%type: unit -> [%t shape] Js.t]
            in
            let marked =
              {
                expression with
                pexp_desc = Pexp_apply (callee, List.map (fun (label, argument) -> (label, super#expression argument)) arguments);
                pexp_attributes = attribute ~loc ~name:{ loc; txt = lazy_props } ~payload:(PStr []) :: expression.pexp_attributes;
              }
            in
            [%expr
              (let module Melact_lazy = struct
                [%%i
                pstr_primitive ~loc
                  {
                    (value_description ~loc ~name:{ loc; txt = "props" } ~type_:made ~prim:[ "" ]) with
                    pval_attributes = [ attribute ~loc ~name:{ loc; txt = "mel.obj" } ~payload:(PStr []) ];
                  }]
              end in
              [%e marked])
              [@warning "-60"]]
        | _ -> super#expression expression
    end
  in
  match imported with [] -> items | _ :: _ -> wrapped#structure items
