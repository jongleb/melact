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

let labels answer =
  match Melhole_typed.Answer.view answer with
  | Melhole_typed.Answer.Function (Melhole_typed.Answer.Unlabelled, props, _) -> (
      match Melhole_typed.Answer.view props with
      | Melhole_typed.Answer.Named { path = "React.props"; arguments = [ labels ]; _ } -> (
          match Melhole_typed.Answer.view labels with
          | Melhole_typed.Answer.Object { fields; _ } ->
              Some
                (List.map
                   (fun (name, field) ->
                     match Melhole_typed.Answer.view field with
                     | Melhole_typed.Answer.Named { path = "option"; _ } -> Ppxlib.Optional name
                     | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Function _ | Melhole_typed.Answer.Js_object _
                     | Melhole_typed.Answer.Object _ | Melhole_typed.Answer.Other ->
                         Ppxlib.Labelled name)
                   fields)
          | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Function _ | Melhole_typed.Answer.Js_object _
          | Melhole_typed.Answer.Other ->
              None)
      | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Function _ | Melhole_typed.Answer.Js_object _
      | Melhole_typed.Answer.Object _ | Melhole_typed.Answer.Other ->
          None)
  | Melhole_typed.Answer.Function ((Melhole_typed.Answer.Labelled _ | Melhole_typed.Answer.Optional _), _, _)
  | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Js_object _ | Melhole_typed.Answer.Object _ | Melhole_typed.Answer.Other ->
      None
