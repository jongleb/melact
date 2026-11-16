open Ppxlib
open QCheck2

let loc = Location.none

let rec value expression =
  match expression.pexp_desc with
  | Pexp_constant (Pconst_string (text, _, _)) -> text
  | Pexp_ident { txt; _ } -> "<" ^ String.concat "." (Longident.flatten_exn txt) ^ ">"
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Ldot (Lident "Stdlib", "^"); _ }; _ }, [ (Nolabel, left); (Nolabel, right) ]) ->
      value left ^ value right
  | _ -> failwith (Pprintast.string_of_expression expression)

let ours text =
  match Melhole_compiler.Interpolation.expanded [ Ast_builder.Default.pstr_eval ~loc (Ast_builder.Default.pexp_constant ~loc (Pconst_string (text, loc, Some "j"))) [] ] with
  | [ { pstr_desc = Pstr_eval ({ pexp_desc = Pexp_constant (Pconst_string (_, _, Some "j")); _ }, _); _ } ] -> `Kept
  | [ { pstr_desc = Pstr_eval (expression, _); _ } ] -> `Expanded (value expression)
  | _ -> failwith "one item in, one item out"

let melange text =
  let literal = Ast_builder.Default.pexp_constant ~loc (Pconst_string (text, loc, Some "j")) in
  match Melange_ppx__String_interp.transform ~loc ~delim:"j" literal text with
  | expression -> `Expanded (value expression)
  | exception _ -> `Kept

let text =
  Gen.(
    map (String.concat "")
      (list_size (int_bound 12)
         (oneof_list [ "a"; "b"; "x1"; "_"; "A"; "."; "'"; "$"; "$("; ")"; "\\"; "\\$"; " "; "\""; "url("; "é"; "$a"; "$(b)"; "$M.c" ])))

let laws =
  [
    Test.make ~count:5000 ~name:"Interpolation: an interpolated string is what melange.ppx makes of it, or kept when melange.ppx rejects it"
      ~print:Print.string text (fun text -> ours text = melange text);
  ]

let () = exit (QCheck_base_runner.run_tests ~verbose:true laws)
