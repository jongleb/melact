(** A Meltea program run by a Melact component, in the component's place in the tree: its view is
    drawn by Melact's scheduler with the rest of the page, so it shares one event delegation and one
    draw per flush. *)

(** A program that takes an ['input] from the component around it and reports ['report]s to it. *)
type ('input, 'report) t

(** [sandbox ~init ~update ~view name]: [init] makes the first model from the first input; each
    later input that is not the one before ([!==]) becomes the message [receive input], if any; each
    message the program sends itself (an event, a command, a subscription) is reported as
    [report message model], with the model it made, if any. Messages made by [receive] are not
    reported: the component around already knows them. [name] names the component in Melact's errors. *)
val sandbox :
  ?receive:('input -> 'msg option) ->
  ?report:('msg -> 'model -> 'report option) ->
  init:('input -> 'model) ->
  update:('msg -> 'model -> 'model) ->
  view:('model -> 'msg Html.t) ->
  string ->
  ('input, 'report) t

(** [sandbox] with commands and subscriptions: unmounting the component stops the subscriptions,
    and what commands send after it is dropped. *)
val element :
  ?receive:('input -> 'msg option) ->
  ?report:('msg -> 'model -> 'report option) ->
  init:('input -> 'model * 'msg Cmd.t) ->
  update:('msg -> 'model -> 'model * 'msg Cmd.t) ->
  view:('model -> 'msg Html.t) ->
  subscriptions:('model -> 'msg Sub.t) ->
  string ->
  ('input, 'report) t

type make_props

val makeProps :
  program:('input, 'report) t -> input:'input -> ?onReport:('report -> unit) -> ?key:string -> unit -> make_props

external make : make_props -> React.element = "%identity"
