open Ppxlib

class mapper =
  object
    inherit Melhole_compiler.Scope.mapper

    method! stateful_call callee =
      match callee.pexp_desc with
      | Pexp_ident { txt; _ } -> (
          match Melhole_compiler.Hook_name.of_name (Longident.last_exn txt) with Hook _ -> `Stateful | Plain -> `Pure)
      | _ -> `Pure
  end
