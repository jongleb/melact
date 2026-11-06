(** The children [React.createElementVariadic] passes on to the DOM element it creates. *)

val with_children : Melhole_server.child array -> (unit -> 'a) -> 'a

(** The children of the [createElementVariadic] call running now, and none from then on. *)
val take : unit -> Melhole_server.child array
