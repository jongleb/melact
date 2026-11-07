(** The values melact-ppx caches in a component: closures, records, arrays and elements written in
    the props of the elements it renders, each kept while the variables it captures are the same
    ([===]), so that a child that receives it sees the same value and is not rendered again. *)

(** The cells of one instance: for each site, the variables it captured last, then its value. *)
type t

(** The cells of the instance being rendered, [count] of them, taken as one hook. *)
val cells : t Hook.key -> int -> t

(** One site's cells in this render; abstract, hence invariant, so the prop's type reaches [store]. *)
type 'value found

val lookup0 : t -> int -> 'value found
val lookup1 : t -> int -> 'a -> 'value found
val lookup2 : t -> int -> 'a -> 'b -> 'value found
val lookup3 : t -> int -> 'a -> 'b -> 'c -> 'value found
val lookup4 : t -> int -> 'a -> 'b -> 'c -> 'd -> 'value found
val lookup : t -> int -> Melhole.View.input array -> 'value found

(** [graph cells at changed mask]: the value kept at [at] while none of the sources in [mask] is
    among those that [changed] since the last render. *)
val graph : t -> int -> int -> int -> 'value found

external kept : 'value found -> 'value option = "%identity"

val store : t -> int -> 'value found -> 'value -> 'value
