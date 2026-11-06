(** Whether the value a [let] binds is only read in the rest of a component's body, so that keeping
    it from an earlier render is invisible: it is never assigned, written to, or handed to anything
    that could change it. *)

type t =
  | Read_only  (** Every use reads it: props, a pure library function, a match, a field, a hook's dependencies. *)
  | Possibly_changed  (** Some use may change it in place, or lets it escape where it could be. *)

(** [uses name body]: how [body] uses the value bound to [name], reading through pipes. *)
val uses : string -> Ppxlib.expression -> t
