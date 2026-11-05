(** reason-react's [React] module for melact. Every hook that keeps state
    takes the key of its call site first; melact-ppx inserts it, so source
    code calls [React.useState init] exactly as with reason-react. *)

(** A piece of UI. *)
type element

external of_child : Melhole.View.child -> element = "%identity"
external to_child : element -> Melhole.View.child = "%identity"

val null : element
val string : string -> element
val int : int -> element
val float : float -> element
val array : element array -> element
val list : element list -> element

(** A mutable box that survives renders. *)
type 'value ref = { mutable current : 'value }

module Context : sig
  (** A value passed down to every component below its provider. *)
  type 'value t = Context of 'value Melact_runtime.Context.t [@@unboxed]

  val provider : 'value t -> value:'value -> children:element -> unit -> element
end

module Fragment : sig
  val make : children:element -> unit -> element
end

module StrictMode : sig
  val make : children:element -> unit -> element
end

module Suspense : sig
  val make : ?fallback:element -> children:element -> unit -> element
end

module Children : sig
  val map : element -> (element -> element) -> element
  val mapWithIndex : element -> (element -> int -> element) -> element
  val forEach : element -> (element -> unit) -> unit
  val forEachWithIndex : element -> (element -> int -> unit) -> unit
  val count : element -> int
  val only : element -> element
  val toArray : element -> element array
end

module Ref : sig
  val current : 'value ref -> 'value
  val setCurrent : 'value ref -> 'value -> unit
end

val createRef : unit -> 'value Js.nullable ref
val isValidElement : element -> bool
val cloneElement : element -> 'props -> element
val setDisplayName : ('props -> element) -> string -> unit
val displayName : ('props -> element) -> string option
val createContext : 'value -> 'value Context.t
val useContext : 'value Context.t -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

(** The slot of a [useState] or [useReducer] call. *)
type ('state, 'action) state

(** The slot of an effect, with the dependencies it last ran with. *)
type 'deps effect_cell

(** The slot of a memo, with its dependencies and value. *)
type ('deps, 'value) memo

val useState :
  ('state, 'state -> 'state) state Melact_runtime.Hook.key ->
  (unit -> 'state) ->
  'state * (('state -> 'state) -> unit)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useReducer :
  ('state, 'action) state Melact_runtime.Hook.key ->
  ('state -> 'action -> 'state) ->
  'state ->
  'state * ('action -> unit)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useReducerWithMapState :
  ('state, 'action) state Melact_runtime.Hook.key ->
  ('state -> 'action -> 'state) ->
  'initial ->
  ('initial -> 'state) ->
  'state * ('action -> unit)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect :
  unit effect_cell Melact_runtime.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect0 :
  unit effect_cell Melact_runtime.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect1 :
  'a array effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a array ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect2 :
  ('a * 'b) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect3 :
  ('a * 'b * 'c) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect4 :
  ('a * 'b * 'c * 'd) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect5 :
  ('a * 'b * 'c * 'd * 'e) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect6 :
  ('a * 'b * 'c * 'd * 'e * 'f) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect :
  unit effect_cell Melact_runtime.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect0 :
  unit effect_cell Melact_runtime.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect1 :
  'a array effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a array ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect2 :
  ('a * 'b) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect3 :
  ('a * 'b * 'c) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect4 :
  ('a * 'b * 'c * 'd) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect5 :
  ('a * 'b * 'c * 'd * 'e) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect6 :
  ('a * 'b * 'c * 'd * 'e * 'f) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo : (unit, 'value) memo Melact_runtime.Hook.key -> (unit -> 'value) -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useMemo0 : (unit, 'value) memo Melact_runtime.Hook.key -> (unit -> 'value) -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo1 :
  ('a array, 'value) memo Melact_runtime.Hook.key -> (unit -> 'value) -> 'a array -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo2 :
  ('a * 'b, 'value) memo Melact_runtime.Hook.key -> (unit -> 'value) -> 'a * 'b -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo3 :
  ('a * 'b * 'c, 'value) memo Melact_runtime.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo4 :
  ('a * 'b * 'c * 'd, 'value) memo Melact_runtime.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo5 :
  ('a * 'b * 'c * 'd * 'e, 'value) memo Melact_runtime.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo6 :
  ('a * 'b * 'c * 'd * 'e * 'f, 'value) memo Melact_runtime.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g, 'value) memo Melact_runtime.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback : (unit, 'fn) memo Melact_runtime.Hook.key -> 'fn -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useCallback0 : (unit, 'fn) memo Melact_runtime.Hook.key -> 'fn -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useCallback1 : ('a array, 'fn) memo Melact_runtime.Hook.key -> 'fn -> 'a array -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useCallback2 : ('a * 'b, 'fn) memo Melact_runtime.Hook.key -> 'fn -> 'a * 'b -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback3 :
  ('a * 'b * 'c, 'fn) memo Melact_runtime.Hook.key -> 'fn -> 'a * 'b * 'c -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback4 :
  ('a * 'b * 'c * 'd, 'fn) memo Melact_runtime.Hook.key -> 'fn -> 'a * 'b * 'c * 'd -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback5 :
  ('a * 'b * 'c * 'd * 'e, 'fn) memo Melact_runtime.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e ->
  'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback6 :
  ('a * 'b * 'c * 'd * 'e * 'f, 'fn) memo Melact_runtime.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g, 'fn) memo Melact_runtime.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useRef : 'value ref Melact_runtime.Hook.key -> 'value -> 'value ref
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect :
  unit effect_cell Melact_runtime.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect0 :
  unit effect_cell Melact_runtime.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect1 :
  'a array effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a array ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect2 :
  ('a * 'b) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect3 :
  ('a * 'b * 'c) effect_cell Melact_runtime.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

(** The slot of a [useSyncExternalStore] call. *)
type 'snapshot store

val useSyncExternalStore :
  'snapshot store Melact_runtime.Hook.key ->
  subscribe:((unit -> unit) -> unit -> unit) ->
  getSnapshot:(unit -> 'snapshot) ->
  'snapshot
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useDebugValue : 'value -> ?format:('value -> string) -> unit -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle0 :
  unit effect_cell Melact_runtime.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle1 :
  'a array effect_cell Melact_runtime.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a array ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle2 :
  ('a * 'b) effect_cell Melact_runtime.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle3 :
  ('a * 'b * 'c) effect_cell Melact_runtime.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle4 :
  ('a * 'b * 'c * 'd) effect_cell Melact_runtime.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle5 :
  ('a * 'b * 'c * 'd * 'e) effect_cell Melact_runtime.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle6 :
  ('a * 'b * 'c * 'd * 'e * 'f) effect_cell Melact_runtime.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g) effect_cell Melact_runtime.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useId : string Melact_runtime.Hook.key -> unit -> string
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useTransition : unit -> bool * ((unit -> unit) -> unit)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val startTransition : (unit -> unit) -> unit
val act : (unit -> unit) -> unit Js.Promise.t
val actAsync : (unit -> unit Js.Promise.t) -> unit Js.Promise.t
val forwardRef : ('props -> 'value ref Js.Nullable.t -> element) -> 'props -> element
val memo : ('props -> element) -> 'props -> element

val memoCustomCompareProps :
  ('props -> element) -> ('props -> 'props -> bool) -> 'props -> element
