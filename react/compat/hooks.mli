(** npm React's hooks on Melact's hook slots, read in call order as React reads them. Each takes
    what JavaScript passes: dependencies are an array or [undefined], an effect returns its cleanup
    or anything else. *)

val useEffect : Raw.t -> Raw.t -> unit
val useLayoutEffect : Raw.t -> Raw.t -> unit
val useInsertionEffect : Raw.t -> Raw.t -> unit
val useState : Raw.t -> Raw.t * (Raw.t -> unit)
val useReducer : Raw.t -> Raw.t -> Raw.t -> Raw.t * (Raw.t -> unit)
val useMemo : Raw.t -> Raw.t -> Raw.t
val useCallback : Raw.t -> Raw.t -> Raw.t
val useRef : Raw.t -> Raw.t React.ref
val useId : unit -> string
val useImperativeHandle : Raw.t -> Raw.t -> Raw.t -> unit
val useSyncExternalStore : Raw.t -> Raw.t -> Raw.t -> Raw.t
val useDebugValue : Raw.t -> Raw.t -> unit
val startTransition : Raw.t -> unit
val useTransition : unit -> bool * (Raw.t -> unit)
val useDeferredValue : Raw.t -> Raw.t -> Raw.t
