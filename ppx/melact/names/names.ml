open Ppxlib

type space = Values | Constructors | Labels | Types | Modules | Classes

let () =
  let exported path =
    let channel = open_in path in
    let signature = Parse.interface (Lexing.from_channel channel) in
    close_in channel;
    List.concat_map
      (fun item ->
        match item.psig_desc with
        | Psig_value { pval_name; _ } -> [ (Values, pval_name.txt) ]
        | Psig_type (_, declarations) | Psig_typesubst declarations ->
            List.concat_map
              (fun declaration ->
                (Types, declaration.ptype_name.txt)
                ::
                (match declaration.ptype_kind with
                | Ptype_variant constructors ->
                    List.map (fun constructor -> (Constructors, constructor.pcd_name.txt)) constructors
                | Ptype_record labels -> List.map (fun label -> (Labels, label.pld_name.txt)) labels
                | Ptype_abstract | Ptype_open -> []))
              declarations
        | Psig_typext { ptyext_constructors; _ } ->
            List.map (fun constructor -> (Constructors, constructor.pext_name.txt)) ptyext_constructors
        | Psig_exception { ptyexn_constructor; _ } -> [ (Constructors, ptyexn_constructor.pext_name.txt) ]
        | Psig_module { pmd_name; _ } -> List.map (fun name -> (Modules, name)) (Option.to_list pmd_name.txt)
        | Psig_modsubst { pms_name; _ } -> [ (Modules, pms_name.txt) ]
        | Psig_recmodule declarations ->
            List.filter_map (fun declaration -> Option.map (fun name -> (Modules, name)) declaration.pmd_name.txt) declarations
        | Psig_modtype { pmtd_name; _ } | Psig_modtypesubst { pmtd_name; _ } -> [ (Modules, pmtd_name.txt) ]
        | Psig_class declarations -> List.map (fun declaration -> (Classes, declaration.pci_name.txt)) declarations
        | Psig_class_type declarations -> List.map (fun declaration -> (Classes, declaration.pci_name.txt)) declarations
        | Psig_open _ | Psig_attribute _ -> []
        | Psig_include _ | Psig_extension _ ->
            Location.raise_errorf ~loc:item.psig_loc "names: React's names behind an include or an extension are unknown")
      signature
  in
  let names = List.concat_map exported (List.tl (Array.to_list Sys.argv)) in
  List.iter
    (fun (space, binding) ->
      Printf.printf "let %s =\n  [\n" binding;
      List.iter (Printf.printf "    %S;\n")
        (List.sort_uniq String.compare
           (List.filter_map (fun (found, name) -> match found = space with true -> Some name | false -> None) names));
      print_string "  ]\n\n")
    [
      (Values, "values");
      (Constructors, "constructors");
      (Labels, "labels");
      (Types, "types");
      (Modules, "modules");
      (Classes, "classes");
    ]
