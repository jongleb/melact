(** Typed hook slots of one component instance, read in call order. *)

(** The type witness of one hook call site, made once per site by melact-ppx. *)
type 'a key

val key : unit -> 'a key

(** One key for every type: what a binding to npm's [react] used from another file calls its hook
    with, so that the binding stays polymorphic. Its call sites are checked in order, not by type. *)
external unchecked : unit key -> 'a key = "%identity"

(** A dependency of an effect or memo, compared by [===] whatever its type. *)
type dependency

(** A tuple of dependencies as the JavaScript array it is, for more dependencies than the
    numbered hooks take. *)
external listed : 'tuple -> dependency array = "%identity"

(** The slots of one instance and the position of the next hook call. *)
type slots

val slots : unit -> slots
val rewind : slots -> unit
val take : slots -> 'a key -> (unit -> 'a) -> 'a

(** The value of the next hook call when an earlier render made it, else [None]: then [put] makes it. *)
val found : slots -> 'a key -> 'a option

val put : slots -> 'a key -> 'a -> unit
