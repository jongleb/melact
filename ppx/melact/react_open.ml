open Ppxlib

let qualified expression =
  let everything =
    React_names.values @ React_names.constructors @ React_names.labels @ React_names.types @ React_names.modules
    @ React_names.classes
  in
  let reader =
    object (self)
      inherit [[ `Free | `Mentioned ]] Ast_traverse.fold as super

      method private read names path found =
        match (found, path) with
        | `Mentioned, _ | `Free, Lapply _ -> `Mentioned
        | `Free, Lident name when List.exists (String.equal name) names -> `Mentioned
        | `Free, Lident _ -> `Free
        | `Free, Ldot (outer, _) -> self#read React_names.modules outer `Free

      method! longident path found = self#read everything path found

      method! expression expression found =
        let found = self#attributes expression.pexp_attributes found in
        match expression.pexp_desc with
        | Pexp_ident { txt; _ } -> self#read React_names.values txt found
        | Pexp_construct ({ txt; _ }, argument) ->
            self#option self#expression argument (self#read React_names.constructors txt found)
        | Pexp_field (record, { txt; _ }) -> self#expression record (self#read React_names.labels txt found)
        | Pexp_record (fields, base) ->
            self#option self#expression base
              (List.fold_left
                 (fun found ({ txt; _ }, value) -> self#expression value (self#read React_names.labels txt found))
                 found fields)
        | _ -> super#expression { expression with pexp_attributes = [] } found

      method! pattern pattern found =
        let found = self#attributes pattern.ppat_attributes found in
        match pattern.ppat_desc with
        | Ppat_var { txt; _ } -> self#read React_names.values (Lident txt) found
        | Ppat_alias (inner, { txt; _ }) -> self#pattern inner (self#read React_names.values (Lident txt) found)
        | Ppat_construct ({ txt; _ }, argument) ->
            self#option (fun (_, inner) -> self#pattern inner) argument (self#read React_names.constructors txt found)
        | Ppat_record (fields, _) ->
            List.fold_left
              (fun found ({ txt; _ }, inner) -> self#pattern inner (self#read React_names.labels txt found))
              found fields
        | _ -> super#pattern { pattern with ppat_attributes = [] } found

      method! core_type core_type found =
        match core_type.ptyp_desc with
        | Ptyp_constr ({ txt; _ }, arguments) ->
            self#list self#core_type arguments
              (self#attributes core_type.ptyp_attributes (self#read React_names.types txt found))
        | _ -> super#core_type core_type found

      method! module_expr module_expr found =
        match module_expr.pmod_desc with
        | Pmod_ident { txt; _ } -> self#attributes module_expr.pmod_attributes (self#read React_names.modules txt found)
        | _ -> super#module_expr module_expr found
    end
  in
  let rec rooted path =
    match path with
    | Lident name -> Some (Ldot (Lident "React", name))
    | Ldot (outer, name) -> Option.map (fun outer -> Ldot (outer, name)) (rooted outer)
    | Lapply _ -> None
  in
  let rec pushed declaration expression =
    let rebuilt desc = { expression with pexp_desc = desc } in
    let wrapped = { expression with pexp_desc = Pexp_open (declaration, expression); pexp_attributes = [] } in
    match
      ( reader#expression { expression with pexp_attributes = [] } `Free,
        reader#attributes expression.pexp_attributes `Free,
        expression.pexp_desc )
    with
    | `Free, `Free, _ -> expression
    | `Mentioned, `Free, Pexp_ident { txt; loc } ->
        Option.fold ~none:wrapped ~some:(fun txt -> rebuilt (Pexp_ident { txt; loc })) (rooted txt)
    | `Mentioned, `Free, Pexp_apply (({ pexp_desc = Pexp_ident { txt = Lident "##"; _ }; _ } as send), [ (label, target); field ]) ->
        rebuilt (Pexp_apply (send, [ (label, pushed declaration target); field ]))
    | `Mentioned, `Free, Pexp_apply (callee, arguments) ->
        rebuilt
          (Pexp_apply
             ( pushed declaration callee,
               List.map (fun (label, argument) -> (label, pushed declaration argument)) arguments ))
    | `Mentioned, `Free, Pexp_sequence (first, rest) ->
        rebuilt (Pexp_sequence (pushed declaration first, pushed declaration rest))
    | `Mentioned, `Free, Pexp_tuple items -> rebuilt (Pexp_tuple (List.map (pushed declaration) items))
    | `Mentioned, `Free, Pexp_array items -> rebuilt (Pexp_array (List.map (pushed declaration) items))
    | `Mentioned, `Free, Pexp_construct (constructor, Some argument) -> (
        match reader#expression { expression with pexp_desc = Pexp_construct (constructor, None); pexp_attributes = [] } `Free with
        | `Free -> rebuilt (Pexp_construct (constructor, Some (pushed declaration argument)))
        | `Mentioned -> wrapped)
    | `Mentioned, `Free, Pexp_ifthenelse (test, yes, no) ->
        rebuilt
          (Pexp_ifthenelse (pushed declaration test, pushed declaration yes, Option.map (pushed declaration) no))
    | `Mentioned, `Free, Pexp_let (flag, bindings, rest) -> (
        match
          List.fold_left
            (fun found binding ->
              reader#value_binding { binding with pvb_expr = Ast_builder.Default.eunit ~loc:binding.pvb_loc } found)
            `Free bindings
        with
        | `Free ->
            rebuilt
              (Pexp_let
                 ( flag,
                   List.map (fun binding -> { binding with pvb_expr = pushed declaration binding.pvb_expr }) bindings,
                   pushed declaration rest ))
        | `Mentioned -> wrapped)
    | `Mentioned, `Free, _ | (`Free | `Mentioned), `Mentioned, _ -> wrapped
  in
  (object
     inherit Ast_traverse.map as super

     method! expression expression =
       let expression = super#expression expression in
       match expression.pexp_desc with
       | Pexp_open (({ popen_expr = { pmod_desc = Pmod_ident { txt = Lident "React"; _ }; _ }; _ } as declaration), body)
         ->
           let opened = pushed declaration body in
           { opened with pexp_attributes = opened.pexp_attributes @ expression.pexp_attributes }
       | _ -> expression
   end)
    #expression
    expression
