(** The identity of one [@react.component], made once per definition and compared physically. *)

(** What a component's render reads: what React lets it read, or more. *)
type rendering =
  | Pure  (** Only its props, state, context and the values of hooks: rendering it at once or later shows the same. *)
  | Impure  (** Possibly the DOM, a ref or another mutable value, or the compiler could not tell. *)

type t = private {
  name : string;  (** For error messages and devtools. *)
  rendering : rendering;
}

val make : name:string -> t
val pure : name:string -> t
