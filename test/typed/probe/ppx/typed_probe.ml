open Ppxlib

let () =
  Driver.register_transformation "typed-probe"
    ~instrument:
      (Driver.Instrument.make ~position:After (fun structure ->
      let immediate = ref 0 and asked = ref 0 and answered = ref 0 in
      let probe =
        object
          inherit Ast_traverse.map as super

          method! expression expression =
            match List.exists (fun attribute -> String.equal attribute.attr_name.txt "JSX") expression.pexp_attributes with
            | true -> Location.raise_errorf ~loc:expression.pexp_loc "typed-probe: runs after melact-ppx, before JSX is left"
            | false -> (
                let expression = super#expression expression in
                match expression.pexp_desc with
                | Pexp_apply (callee, arguments) ->
                    {
                      expression with
                      pexp_desc =
                        Pexp_apply
                          ( callee,
                            List.map
                              (fun (label, argument) ->
                                match (label, argument.pexp_desc) with
                                | (Nolabel | Labelled _), Pexp_ident { txt = Lident _; _ } ->
                                    incr asked;
                                    let question, marked = Melhole_typed.Question.expression argument in
                                    ( label,
                                      Melhole_typed.Site.expression marked ~decide:(fun file argument ->
                                          let found = Option.map Melhole_typed.Mutability.of_answer (Melhole_typed.File.answer file question) in
                                          Option.iter (fun _ -> incr answered) found;
                                          match found with
                                          | Some Melhole_typed.Mutability.Immediate ->
                                              incr immediate;
                                              let loc = argument.pexp_loc in
                                              [%expr Typed_probe_runtime.immediate [%e argument]]
                                          | Some
                                              ( Melhole_typed.Mutability.Immutable_boxed | Melhole_typed.Mutability.Mutable_inside
                                              | Melhole_typed.Mutability.Unknown )
                                          | None ->
                                              argument) )
                                | (Nolabel | Labelled _ | Optional _), _ -> (label, argument))
                              arguments );
                    }
                | _ -> expression)
        end
      in
      let probed = probe#structure structure in
      let loc = Location.none in
      let file = Ast_builder.Default.estring ~loc (Filename.basename !Ocaml_common.Location.input_name) in
      probed
      @ Melhole_typed.Site.items
          [ [%stri let () = Typed_probe_runtime.untyped [%e file]] ]
          ~decide:(fun _ _ ->
            [
              [%stri
                let () =
                  Typed_probe_runtime.typed [%e file] ~asked:[%e Ast_builder.Default.eint ~loc !asked]
                    ~answered:[%e Ast_builder.Default.eint ~loc !answered] ~immediate:[%e Ast_builder.Default.eint ~loc !immediate]];
            ])))
