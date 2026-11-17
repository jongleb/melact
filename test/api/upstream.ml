open Ppxlib

let () =
  let name = Sys.argv.(1) in
  let lines =
    In_channel.with_open_text Sys.argv.(2) In_channel.input_all
    |> String.split_on_char '\n'
    |> List.filter_map (fun line ->
           match String.split_on_char ' ' (String.trim line) with
           | "" :: _ | [] -> None
           | path :: "differs" :: _ -> Some (path, `Differs)
           | path :: _ -> Some (path, `Missing))
  in
  let escaped label = match Keyword.is_keyword label with true -> "\\#" ^ label | false -> label in
  let raw =
    In_channel.input_all stdin |> String.split_on_char '\n'
    |> List.map (fun line ->
           Option.fold ~none:line
             ~some:(fun colon ->
               let rec start index = match line.[index] with ' ' | '\t' -> start (index + 1) | _ -> index in
               String.sub line 0 (start 0)
               ^ escaped (String.sub line (start 0) (colon - start 0))
               ^ String.sub line colon (String.length line - colon))
             (String.index_opt line ':'))
    |> String.concat "\n"
  in
  let constructed status declaration =
    let loc = declaration.ptype_loc in
    let own = Ast_builder.Default.ptyp_constr ~loc { loc; txt = Lident declaration.ptype_name.txt } [] in
    let derivers =
      List.concat_map
        (fun attribute ->
          match (attribute.attr_name.txt, attribute.attr_payload) with
          | "deriving", PStr [ { pstr_desc = Pstr_eval ({ pexp_desc = Pexp_tuple derivers; _ }, _); _ } ] ->
              List.filter_map (fun deriver -> match deriver.pexp_desc with Pexp_ident { txt = Lident named; _ } -> Some named | _ -> None) derivers
          | "deriving", PStr [ { pstr_desc = Pstr_eval ({ pexp_desc = Pexp_ident { txt = Lident named; _ }; _ }, _); _ } ] -> [ named ]
          | _ -> [])
        declaration.ptype_attributes
    in
    let value name type_ =
      Ast_builder.Default.psig_value ~loc (Ast_builder.Default.value_description ~loc ~name:{ loc; txt = name } ~type_ ~prim:[])
    in
    match declaration.ptype_kind with
    | Ptype_record fields ->
        List.concat_map
          (fun deriver ->
            match (deriver, status (declaration.ptype_name.txt ^ "[" ^ deriver ^ "]")) with
            | "jsProperties", `Kept ->
                [
                  value declaration.ptype_name.txt
                    (List.fold_right
                       (fun field result ->
                         match field.pld_type.ptyp_desc with
                         | Ptyp_constr ({ txt = Lident "option"; _ }, [ inner ])
                           when List.exists (fun attribute -> String.equal attribute.attr_name.txt "mel.optional") field.pld_attributes ->
                             Ast_builder.Default.ptyp_arrow ~loc (Optional (escaped field.pld_name.txt)) inner result
                         | _ -> Ast_builder.Default.ptyp_arrow ~loc (Labelled (escaped field.pld_name.txt)) field.pld_type result)
                       fields [%type: unit -> [%t own]]);
                ]
            | "getSet", `Kept -> List.map (fun field -> value (field.pld_name.txt ^ "Get") [%type: [%t own] -> [%t field.pld_type]]) fields
            | _ -> [])
          derivers
    | _ -> []
  in
  let rec without path items =
    let status named = Option.value ~default:`Kept (List.assoc_opt (String.concat "." (path @ [ named ])) lines) in
    List.concat_map
      (fun item ->
        match item.psig_desc with
        | Psig_value { pval_name; _ } -> ( match status pval_name.txt with `Kept -> [ item ] | `Missing | `Differs -> [])
        | Psig_type (flag, declarations) -> (
            let derived attribute =
              match (attribute.attr_name.txt, attribute.attr_payload) with
              | "deriving", PStr [ ({ pstr_desc = Pstr_eval (({ pexp_desc = Pexp_tuple derivers; _ } as tuple), extra); _ } as payload) ] ->
                  let kept =
                    List.filter
                      (fun deriver ->
                        match deriver.pexp_desc with
                        | Pexp_ident { txt = Lident named; _ } ->
                            List.for_all
                              (fun declaration ->
                                match status (declaration.ptype_name.txt ^ "[" ^ named ^ "]") with `Kept -> true | `Missing | `Differs -> false)
                              declarations
                        | _ -> true)
                      derivers
                  in
                  { attribute with attr_payload = PStr [ { payload with pstr_desc = Pstr_eval ({ tuple with pexp_desc = Pexp_tuple kept }, extra) } ] }
              | _ -> attribute
            in
            let made =
              List.concat_map
                (fun declaration -> match status declaration.ptype_name.txt with `Differs -> constructed status declaration | `Kept | `Missing -> [])
                declarations
            in
            match
              List.filter_map
                (fun declaration ->
                  match status declaration.ptype_name.txt with
                  | `Differs -> Some { declaration with ptype_kind = Ptype_abstract; ptype_manifest = None; ptype_attributes = [] }
                  | `Kept -> Some { declaration with ptype_attributes = List.map derived declaration.ptype_attributes }
                  | `Missing -> None)
                declarations
            with
            | [] -> made
            | kept -> { item with psig_desc = Psig_type (flag, kept) } :: made)
        | Psig_module ({ pmd_name = { txt = Some named; _ }; pmd_type; _ } as declaration) -> (
            match (status named, pmd_type.pmty_desc) with
            | (`Missing | `Differs), _ -> []
            | `Kept, Pmty_signature inner ->
                [
                  {
                    item with
                    psig_desc =
                      Psig_module { declaration with pmd_type = { pmd_type with pmty_desc = Pmty_signature (without (path @ [ named ]) inner) } };
                  };
                ]
            | `Kept, _ -> [ item ])
        | _ -> [ item ])
      items
  in
  let valued =
    object (self)
      inherit Ast_traverse.map as super

      method! core_type typ =
        super#core_type
          { typ with ptyp_attributes = List.filter (fun attribute -> not (String.starts_with ~prefix:"mel." attribute.attr_name.txt)) typ.ptyp_attributes }

      method! row_field field =
        super#row_field
          { field with prf_attributes = List.filter (fun attribute -> not (String.starts_with ~prefix:"mel." attribute.attr_name.txt)) field.prf_attributes }

      method! label_declaration declaration =
        super#label_declaration
          {
            declaration with
            pld_name =
              {
                declaration.pld_name with
                txt = escaped declaration.pld_name.txt;
              };
          }

      method! signature items =
        List.concat_map
          (fun item ->
            match item.psig_desc with
            | Psig_value description
              when List.exists (fun attribute -> String.equal attribute.attr_name.txt "react.component") description.pval_attributes ->
                let loc = item.psig_loc in
                let rec props typ =
                  match typ.ptyp_desc with
                  | Ptyp_arrow (Labelled label, argument, result) -> (label, argument) :: props result
                  | Ptyp_arrow (Optional label, argument, result) -> (label, [%type: [%t argument] option]) :: props result
                  | _ -> []
                in
                let fields = props description.pval_type in
                let shape =
                  Ast_builder.Default.ptyp_constr ~loc { loc; txt = Ldot (Lident "Js", "t") }
                    [
                      Ast_builder.Default.ptyp_object ~loc
                        (List.map (fun (label, field) -> Ast_builder.Default.otag ~loc { loc; txt = label } field) fields)
                        Closed;
                    ]
                in
                let rec arguments typ =
                  match typ.ptyp_desc with
                  | Ptyp_arrow (((Labelled _ | Optional _) as label), argument, result) ->
                      Ast_builder.Default.ptyp_arrow ~loc label argument (arguments result)
                  | _ -> [%type: ?key:string -> unit -> [%t shape]]
                in
                [
                  Ast_builder.Default.psig_value ~loc
                    (Ast_builder.Default.value_description ~loc ~name:{ loc; txt = "makeProps" } ~type_:(arguments description.pval_type) ~prim:[]);
                  Ast_builder.Default.psig_value ~loc
                    (Ast_builder.Default.value_description ~loc ~name:description.pval_name
                       ~type_:[%type: [%t shape] React.component] ~prim:[]);
                ]
            | _ -> [ self#signature_item item ])
          items

      method! signature_item item =
        match item.psig_desc with
        | Psig_value ({ pval_type = { ptyp_attributes = _ :: _ as moved; _ } as typ; _ } as description)
          when List.exists (fun attribute -> String.equal attribute.attr_name.txt "deprecated") moved ->
            self#signature_item
              {
                item with
                psig_desc =
                  Psig_value { description with pval_type = { typ with ptyp_attributes = [] }; pval_attributes = description.pval_attributes @ moved };
              }
        | Psig_value ({ pval_prim = _ :: _; _ } as description) ->
            let rec given typ =
              match typ.ptyp_desc with
              | Ptyp_arrow (Nolabel, argument, result)
                when List.exists (fun attribute -> String.equal attribute.attr_name.txt "mel.as") argument.ptyp_attributes ->
                  given result
              | Ptyp_arrow (label, argument, result) -> { typ with ptyp_desc = Ptyp_arrow (label, argument, given result) }
              | _ -> typ
            in
            let description = { description with pval_type = given description.pval_type } in
            super#signature_item {
              item with
              psig_desc =
                Psig_value
                  {
                    description with
                    pval_prim = [];
                    pval_attributes =
                      List.filter
                        (fun attribute -> not (String.starts_with ~prefix:"mel." attribute.attr_name.txt))
                        description.pval_attributes;
                  };
            }
        | _ -> super#signature_item item
    end
  in
  let rec split path items =
    List.fold_right
      (fun item (kept, values) ->
        match item.psig_desc with
        | Psig_value description -> (kept, (path, description) :: values)
        | Psig_module ({ pmd_name = { txt = Some named; _ }; pmd_type = { pmty_desc = Pmty_signature inner; _ } as typ; _ } as declaration) ->
            let inner, found = split (path @ [ named ]) inner in
            ( { item with psig_desc = Psig_module { declaration with pmd_type = { typ with pmty_desc = Pmty_signature inner } } } :: kept,
              found @ values )
        | _ -> (item :: kept, values))
      items ([], [])
  in
  let kept, values = split [] (valued#signature (without [] (Parse.interface (Lexing.from_string raw)))) in
  let called (path, description) =
    let fresh = ref 0 in
    let named =
      object
        inherit Ast_traverse.map as super

        method! core_type typ =
          match typ.ptyp_desc with
          | Ptyp_any ->
              incr fresh;
              { typ with ptyp_desc = Ptyp_var (Printf.sprintf "any%d" !fresh) }
          | _ -> super#core_type typ
      end
    in
    let rec once seen typ =
      match typ.ptyp_desc with
      | Ptyp_arrow (((Labelled label | Optional label) as given), argument, result) -> (
          match List.mem label seen with
          | true -> once seen result
          | false -> { typ with ptyp_desc = Ptyp_arrow (given, argument, once (label :: seen) result) })
      | Ptyp_arrow (Nolabel, argument, result) -> { typ with ptyp_desc = Ptyp_arrow (Nolabel, argument, once seen result) }
      | _ -> typ
    in
    let typ = once [] (named#core_type description.pval_type) in
    let variables =
      (object
         inherit [string list] Ast_traverse.fold as super

         method! core_type typ found =
           match typ.ptyp_desc with
           | Ptyp_var variable when not (List.mem variable found) -> super#core_type typ (found @ [ variable ])
           | _ -> super#core_type typ found
      end)
        #core_type typ []
    in
    let rec arguments index typ =
      match typ.ptyp_desc with
      | Ptyp_arrow (Labelled label, _, result) -> ("~" ^ label) :: arguments index result
      | Ptyp_arrow (Optional label, _, result) -> ("?" ^ label) :: arguments index result
      | Ptyp_arrow (Nolabel, _, result) -> Printf.sprintf "a%d" index :: arguments (index + 1) result
      | _ -> []
    in
    let given = arguments 0 typ in
    Format.asprintf "module _ = struct@,  %s@,  let _check : %s%a =@,    %s%s@,end"
      (String.concat " " (List.map (fun opened -> "open! " ^ opened ^ " [@@warning \"-33\"]") (name :: path)))
      (match variables with [] -> "" | _ -> String.concat " " (List.map (fun variable -> "'" ^ variable) variables) ^ ". ")
      Pprintast.core_type typ
      (match given with [] -> "" | _ -> "fun " ^ String.concat " " given ^ " -> ")
      (String.concat " " (String.concat "." (name :: path @ [ description.pval_name.txt ]) :: given))
  in
  Format.printf "@[<v>[@@@@@@alert \"-deprecated\"]@,[@@@@@@alert \"-unsupported\"]@,module type Upstream = sig@,%a@,end@,module _ : Upstream = %s@,%s@]@." Pprintast.signature kept name
    (String.concat "\n" (List.map called values))
