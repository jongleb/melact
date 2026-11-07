(** npm React's element API, as [react.js] exports it: elements, refs, contexts, wrappers and
    [Children], following React 18's code. *)

val version : string
val create : Raw.t -> Raw.t -> Raw.t array -> Raw.t
val jsx : Raw.t -> Raw.t -> Raw.t -> Raw.t
val clone : Raw.t -> Raw.t -> Raw.t array -> Raw.t
val isValidElement : Raw.t -> bool
val createRef : unit -> Raw.t
val createContext : Raw.t -> Raw.t
val forwardRef : Raw.t -> Raw.t
val memo : Raw.t -> Raw.t -> Raw.t
val lazy_ : Raw.t -> Raw.t
val fragment : Raw.t
val strictMode : Raw.t
val profiler : Raw.t
val suspense : Raw.t
val childrenMap : Raw.t -> Raw.t -> Raw.t -> Raw.t
val childrenForEach : Raw.t -> Raw.t -> Raw.t -> unit
val childrenCount : Raw.t -> int
val childrenToArray : Raw.t -> Raw.t
val childrenOnly : Raw.t -> Raw.t

(** Renders everything pending and runs its effects, as React's [act] does at the end of its scope. *)
val settled : unit -> unit
