(** Elm-style applications over [View], for code without hooks. Messages
    are applied at once and the view is patched once per microtask. *)

val sandbox :
  init:'model ->
  update:('msg -> 'model -> 'model) ->
  view:(('msg -> unit) -> 'model -> Melact_view.View.child) ->
  Dom.element ->
  unit
