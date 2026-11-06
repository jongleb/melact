(** Typed hook slots of one component render, read in call order, as on the client. *)

(** The type witness of one hook call site, made once per site by melact-ppx. *)
type 'a key

val key : unit -> 'a key

(** One key for every type: what a binding to npm's [react] calls its hook with. *)
external unchecked : unit key -> 'a key = "%identity"

(** A dependency of an effect or memo, whatever its type. *)
type dependency

external listed : 'tuple -> dependency array = "%identity"

(** The slots of one component and the position of the next hook call. *)
type slots

val slots : unit -> slots
val rewind : slots -> unit

(** The value of the next hook call when an earlier pass made it, else [None]: then [put] makes it. *)
val found : slots -> 'a key -> 'a option

val put : slots -> 'a key -> 'a -> unit
