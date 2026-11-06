(** A value passed down to the components a provider writes. *)
type 'value t

val make : 'value -> 'value t
val read : 'value t -> 'value

(** Writes [child] with the context holding [value], and the value around it afterwards. *)
val provide : 'value t -> 'value -> Melhole_server.child -> Melhole_server.child
