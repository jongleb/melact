(** The identity of one [@react.component], made once per definition. *)

type 'props t = private {
  name : string;  (** For error messages and devtools. *)
  witness : 'props Type.Id.t;
  unchanged : 'props -> 'props -> bool;  (** Every prop physically equal. *)
}

val make : name:string -> unchanged:('props -> 'props -> bool) -> 'props t
