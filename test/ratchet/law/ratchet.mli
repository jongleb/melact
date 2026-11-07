(** What the ratchet's test files share. Each file loads at most one build that carries melhole, since
    every copy of melhole delegates events from [document] and two copies would both deliver a click. *)

(** How Law A holds Melact to React's count of a kind. *)
type comparison =
  | Compared  (** Never more than React, in any step of any program. *)
  | Known_gap of string  (** More than React today: the total excess on the fixed runs may only shrink. *)
  | Excluded of string  (** Not comparable. *)

(** What each step of a run counted, and the page it ended on. *)
type outcome = Counters.t array * string

(** One fixed program run under React 18 and under Melact. *)
type paired = { name : string; react : outcome; melact : outcome }

val comparison : Counters.kind -> comparison
val loaded : string -> 'build Js.Promise.t
val path_of : string -> string -> string
val seeded : int -> int array
val sequenced : (unit -> 'result Js.Promise.t) list -> 'result list Js.Promise.t
val total : outcome -> Counters.kind -> int
val excess : outcome -> outcome -> Counters.kind -> int
val exceeding : outcome -> outcome -> string array
val gaps : paired list -> (Counters.kind * int) list
val never_more_than_react : gaps:string -> paired list -> unit
val never_more_than_last_time : part:string -> owned:string list -> (string * (Counters.kind * int) list) list -> unit
