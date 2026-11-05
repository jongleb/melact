(** The children [React.createElementVariadic] passes on to the element it creates. *)

val with_children : Melhole.View.child array -> (unit -> 'a) -> 'a

(** The children of the [createElementVariadic] call running now, and none from then on. *)
val take : unit -> Melhole.View.child array
