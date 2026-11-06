type component = Compiled | Of_props of Melhole_typed.Answer.t

let element answer =
  match Melhole_typed.Answer.view answer with
  | Melhole_typed.Answer.Named { path = "React.element"; arguments = []; _ } -> `Element
  | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Function _ | Melhole_typed.Answer.Js_object _
  | Melhole_typed.Answer.Other ->
      `Other

let component answer =
  match Melhole_typed.Answer.view answer with
  | Melhole_typed.Answer.Function (Melhole_typed.Answer.Unlabelled, props, result) -> (
      match (element result, Melhole_typed.Answer.view props) with
      | `Other, _ -> None
      | `Element, Melhole_typed.Answer.Named { path; arguments = []; representation = Melhole_typed.Answer.Abstract }
        when String.ends_with ~suffix:"_props" path ->
          Some Compiled
      | `Element, Melhole_typed.Answer.Named { path; arguments = []; representation = Melhole_typed.Answer.Unboxed held }
        when String.ends_with ~suffix:"_props" path && element held = `Element ->
          Some Compiled
      | `Element, (Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Function _ | Melhole_typed.Answer.Js_object _ | Melhole_typed.Answer.Other) ->
          Some (Of_props props))
  | Melhole_typed.Answer.Function ((Melhole_typed.Answer.Labelled _ | Melhole_typed.Answer.Optional _), _, _)
  | Melhole_typed.Answer.Named _ | Melhole_typed.Answer.Js_object _ | Melhole_typed.Answer.Other ->
      None
