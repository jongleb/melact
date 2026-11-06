(** The dependencies of a memo, compared as React does, by [===] item by item. *)

type change = Same | Changed

val always : unit -> unit -> change
val never : unit -> unit -> change
val array : 'a array -> 'a array -> change
val two : 'a * 'b -> 'a * 'b -> change
val three : 'a * 'b * 'c -> 'a * 'b * 'c -> change
val four : 'a * 'b * 'c * 'd -> 'a * 'b * 'c * 'd -> change
val five : 'a * 'b * 'c * 'd * 'e -> 'a * 'b * 'c * 'd * 'e -> change
val six : 'a * 'b * 'c * 'd * 'e * 'f -> 'a * 'b * 'c * 'd * 'e * 'f -> change
val seven : 'a * 'b * 'c * 'd * 'e * 'f * 'g -> 'a * 'b * 'c * 'd * 'e * 'f * 'g -> change
