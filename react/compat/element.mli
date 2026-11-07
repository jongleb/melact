(** React's elements: plain objects marked with React 18's [$$typeof] symbols, so that [react-is]
    and libraries that inspect elements recognise them. *)

(** The [$$typeof] of an element and of the objects React's API returns. *)
module Mark : sig
  val element : Raw.t
  val portal : Raw.t
  val fragment : Raw.t
  val strict_mode : Raw.t
  val profiler : Raw.t
  val suspense : Raw.t
  val provider : Raw.t
  val context : Raw.t
  val forward_ref : Raw.t
  val memo : Raw.t
  val lazy_ : Raw.t
end

(** [Some element] when the value is an element. *)
val of_value : Raw.t -> Raw.t option

(** [create kind config children], as [React.createElement]: [key] and [ref] taken out of the
    config, one child as [children] itself, several as an array, default props filled in. *)
val create : Raw.t -> Raw.t -> Raw.t array -> Raw.t

(** [jsx kind props key], as [react/jsx-runtime]'s [jsx] and [jsxs]. *)
val jsx : Raw.t -> Raw.t -> Raw.t -> Raw.t

(** [clone element config children], as [React.cloneElement]. *)
val clone : Raw.t -> Raw.t -> Raw.t array -> Raw.t

(** The same element under another key. *)
val rekeyed : Raw.t -> string -> Raw.t

val kind : Raw.t -> Raw.t
val props : Raw.t -> Raw.t
val reference : Raw.t -> Raw.t
val key : Raw.t -> string option
