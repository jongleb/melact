(** The values melact-ppx caches in a component: closures, records, arrays and elements written in
    the props of the elements it renders, each kept while the variables it captures are the same
    ([===]), so that a child that receives it sees the same value and is not rendered again. *)

(** The cells of one instance: for each site, the variables it captured last, then its value. *)
type t

(** The cells of the instance being rendered, [count] of them, taken as one hook. *)
val cells : t Hook.key -> int -> t

(** [cachedK cells at d1 … dK make]: the value at [at + K] when [d1 … dK] are the ones in the cells
    from [at], else [make ()], kept there with them. *)
val cached0 : t -> int -> (unit -> 'value) -> 'value

val cached1 : t -> int -> 'a -> (unit -> 'value) -> 'value
val cached2 : t -> int -> 'a -> 'b -> (unit -> 'value) -> 'value
val cached3 : t -> int -> 'a -> 'b -> 'c -> (unit -> 'value) -> 'value
val cached4 : t -> int -> 'a -> 'b -> 'c -> 'd -> (unit -> 'value) -> 'value

(** For more captures than [cached4] takes; the value is at [at + Array.length captures]. *)
val cached : t -> int -> Melhole.View.input array -> (unit -> 'value) -> 'value
