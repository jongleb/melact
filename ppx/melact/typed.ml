type component = Compiled | Of_props of Melhole_typed.Answer.t

let element answer =
  match Melhole_typed.Answer.view answer with
  | Melhole_typed.Answer.Named { path = "React.element"; arguments = []; _ } -> `Element
  | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Function _ | Melhole_typed.Answer.Js_object _ | Melhole_typed.Answer.Object _
  | Melhole_typed.Answer.Other ->
      `Other

let component answer =
  match Melhole_typed.Answer.view answer with
  | Melhole_typed.Answer.Function (Melhole_typed.Answer.Unlabelled, props, result) -> (
      match (element result, Melhole_typed.Answer.view props) with
      | `Other, _ -> None
      | `Element, Melhole_typed.Answer.Named { path = "React.props"; arguments = [ _ ]; _ } -> Some Compiled
      | `Element, (Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Function _ | Melhole_typed.Answer.Js_object _ | Melhole_typed.Answer.Object _ | Melhole_typed.Answer.Other) ->
          Some (Of_props props))
  | Melhole_typed.Answer.Function ((Melhole_typed.Answer.Labelled _ | Melhole_typed.Answer.Optional _), _, _)
  | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Js_object _ | Melhole_typed.Answer.Object _ | Melhole_typed.Answer.Other ->
      None

let builder_labels answer builder =
  match component answer with
  | Some Compiled ->
      Option.bind (Ocaml_common.Longident.unflatten (Ppxlib.Longident.flatten_exn builder)) (fun builder ->
          match Ocaml_common.Env.find_value_by_name builder answer.Melhole_typed.Answer.env with
          | exception Not_found -> None
          | _, description ->
              let rec labels taken =
                match Melhole_typed.Answer.view taken with
                | Melhole_typed.Answer.Function (Melhole_typed.Answer.Labelled name, _, rest) ->
                    Option.map (List.cons (Ppxlib.Labelled name)) (labels rest)
                | Melhole_typed.Answer.Function (Melhole_typed.Answer.Optional name, _, rest) ->
                    Option.map (List.cons (Ppxlib.Optional name)) (labels rest)
                | Melhole_typed.Answer.Function (Melhole_typed.Answer.Unlabelled, _, _) -> Some []
                | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Js_object _ | Melhole_typed.Answer.Object _
                | Melhole_typed.Answer.Other ->
                    None
              in
              labels (Melhole_typed.Answer.make answer.Melhole_typed.Answer.env description.val_type))
  | Some (Of_props _) | None -> None
