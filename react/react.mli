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
val createElement : 'make -> ('make -> element) -> element

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

(** React's synthetic events, as reason-react declares them; in Melact they are the native DOM events. *)
module Event :
sig
  type 'a synthetic
  external ofNative : Dom.event -> 'a synthetic = "%identity"
  module Synthetic :
  sig
    type tag
    type t = tag synthetic
    external bubbles : 'a synthetic -> bool = "bubbles"[@@mel.get]
    external cancelable : 'a synthetic -> bool = "cancelable"[@@mel.get]
    external currentTarget :
      'a synthetic -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : 'a synthetic -> bool = "defaultPrevented"
    [@@mel.get]
    external eventPhase : 'a synthetic -> int = "eventPhase"[@@mel.get]
    external isTrusted : 'a synthetic -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : 'a synthetic -> < .. >  Js.t = "%identity"
    external preventDefault : 'a synthetic -> unit = "preventDefault"
    [@@mel.send]
    external isDefaultPrevented : 'a synthetic -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : 'a synthetic -> unit = "stopPropagation"
    [@@mel.send]
    external isPropagationStopped : 'a synthetic -> bool = "cancelBubble" [@@mel.get]
    external target : 'a synthetic -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : 'a synthetic -> float = "timeStamp"[@@mel.get]
    external type_ : 'a synthetic -> string = "type"[@@mel.get]
    external persist : 'a synthetic -> unit = "%ignore"
  end
  external toSyntheticEvent : 'a synthetic -> Synthetic.t = "%identity"
  module Clipboard :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external clipboardData : t -> < .. >  Js.t = "clipboardData"[@@mel.get]
  end
  module Composition :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external data : t -> string = "data"[@@mel.get]
  end
  module Drag :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external altKey : t -> bool = "altKey"[@@mel.get]
    external button : t -> int = "button"[@@mel.get]
    external buttons : t -> int = "buttons"[@@mel.get]
    external clientX : t -> int = "clientX"[@@mel.get]
    external clientY : t -> int = "clientY"[@@mel.get]
    external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
    external getModifierState : t -> string -> bool = "getModifierState"
    [@@mel.send]
    external metaKey : t -> bool = "metaKey"[@@mel.get]
    external movementX : t -> int = "movementX"[@@mel.get]
    external movementY : t -> int = "movementY"[@@mel.get]
    external pageX : t -> int = "pageX"[@@mel.get]
    external pageY : t -> int = "pageY"[@@mel.get]
    external relatedTarget : t -> < .. >  Js.t option = "relatedTarget"
    [@@mel.get][@@mel.return nullable]
    external screenX : t -> int = "screenX"[@@mel.get]
    external screenY : t -> int = "screenY"[@@mel.get]
    external shiftKey : t -> bool = "shiftKey"[@@mel.get]
    external dataTransfer : t -> < .. >  Js.t = "dataTransfer"[@@mel.get]
  end
  module Keyboard :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external altKey : t -> bool = "altKey"[@@mel.get]
    external charCode : t -> int = "charCode"[@@mel.get]
    external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
    external getModifierState : t -> string -> bool = "getModifierState"
    [@@mel.send]
    external key : t -> string = "key"[@@mel.get]
    external keyCode : t -> int = "keyCode"[@@mel.get]
    external locale : t -> string = "locale"[@@mel.get]
    external location : t -> int = "location"[@@mel.get]
    external metaKey : t -> bool = "metaKey"[@@mel.get]
    external repeat : t -> bool = "repeat"[@@mel.get]
    external shiftKey : t -> bool = "shiftKey"[@@mel.get]
    external which : t -> int = "which"[@@mel.get]
  end
  module Focus :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external relatedTarget : t -> < .. >  Js.t option = "relatedTarget"
    [@@mel.get][@@mel.return nullable]
  end
  module Form :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
  end
  module Mouse :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external altKey : t -> bool = "altKey"[@@mel.get]
    external button : t -> int = "button"[@@mel.get]
    external buttons : t -> int = "buttons"[@@mel.get]
    external clientX : t -> int = "clientX"[@@mel.get]
    external clientY : t -> int = "clientY"[@@mel.get]
    external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
    external getModifierState : t -> string -> bool = "getModifierState"
    [@@mel.send]
    external metaKey : t -> bool = "metaKey"[@@mel.get]
    external movementX : t -> int = "movementX"[@@mel.get]
    external movementY : t -> int = "movementY"[@@mel.get]
    external pageX : t -> int = "pageX"[@@mel.get]
    external pageY : t -> int = "pageY"[@@mel.get]
    external relatedTarget : t -> < .. >  Js.t option = "relatedTarget"
    [@@mel.get][@@mel.return nullable]
    external screenX : t -> int = "screenX"[@@mel.get]
    external screenY : t -> int = "screenY"[@@mel.get]
    external shiftKey : t -> bool = "shiftKey"[@@mel.get]
  end
  module Pointer :
  sig
    type tag
    type t = tag synthetic
    external type_ : t -> string = "type"[@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external persist : t -> unit = "%ignore"
    external detail : t -> int = "detail"[@@mel.get]
    external view : t -> Dom.window = "view"[@@mel.get]
    external screenX : t -> int = "screenX"[@@mel.get]
    external screenY : t -> int = "screenY"[@@mel.get]
    external clientX : t -> int = "clientX"[@@mel.get]
    external clientY : t -> int = "clientY"[@@mel.get]
    external pageX : t -> int = "pageX"[@@mel.get]
    external pageY : t -> int = "pageY"[@@mel.get]
    external movementX : t -> int = "movementX"[@@mel.get]
    external movementY : t -> int = "movementY"[@@mel.get]
    external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
    external shiftKey : t -> bool = "shiftKey"[@@mel.get]
    external altKey : t -> bool = "altKey"[@@mel.get]
    external metaKey : t -> bool = "metaKey"[@@mel.get]
    external getModifierState : t -> string -> bool = "getModifierState"
    [@@mel.send]
    external button : t -> int = "button"[@@mel.get]
    external buttons : t -> int = "buttons"[@@mel.get]
    external relatedTarget : t -> < .. >  Js.t option = "relatedTarget"
    [@@mel.get][@@mel.return nullable]
    external pointerId : t -> Dom.eventPointerId = "pointerId"[@@mel.get]
    external width : t -> float = "width"[@@mel.get]
    external height : t -> float = "height"[@@mel.get]
    external pressure : t -> float = "pressure"[@@mel.get]
    external tangentialPressure : t -> float = "tangentialPressure"
    [@@mel.get]
    external tiltX : t -> int = "tiltX"[@@mel.get]
    external tiltY : t -> int = "tiltY"[@@mel.get]
    external twist : t -> int = "twist"[@@mel.get]
    external pointerType : t -> string = "pointerType"[@@mel.get]
    external isPrimary : t -> bool = "isPrimary"[@@mel.get]
  end
  module Selection :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
  end
  module Touch :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external altKey : t -> bool = "altKey"[@@mel.get]
    external changedTouches : t -> < .. >  Js.t = "changedTouches"
    [@@mel.get]
    external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
    external getModifierState : t -> string -> bool = "getModifierState"
    [@@mel.send]
    external metaKey : t -> bool = "metaKey"[@@mel.get]
    external shiftKey : t -> bool = "shiftKey"[@@mel.get]
    external targetTouches : t -> < .. >  Js.t = "targetTouches"[@@mel.get]
    external touches : t -> < .. >  Js.t = "touches"[@@mel.get]
  end
  module UI :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external detail : t -> int = "detail"[@@mel.get]
    external view : t -> Dom.window = "view"[@@mel.get]
  end
  module Wheel :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external deltaMode : t -> int = "deltaMode"[@@mel.get]
    external deltaX : t -> float = "deltaX"[@@mel.get]
    external deltaY : t -> float = "deltaY"[@@mel.get]
    external deltaZ : t -> float = "deltaZ"[@@mel.get]
  end
  module Media :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
  end
  module Image :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
  end
  module Animation :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external animationName : t -> string = "animationName"[@@mel.get]
    external pseudoElement : t -> string = "pseudoElement"[@@mel.get]
    external elapsedTime : t -> float = "elapsedTime"[@@mel.get]
  end
  module Transition :
  sig
    type tag
    type t = tag synthetic
    external bubbles : t -> bool = "bubbles"[@@mel.get]
    external cancelable : t -> bool = "cancelable"[@@mel.get]
    external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
    external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
    external eventPhase : t -> int = "eventPhase"[@@mel.get]
    external isTrusted : t -> bool = "isTrusted"[@@mel.get]
    external nativeEvent : t -> < .. >  Js.t = "%identity"
    external preventDefault : t -> unit = "preventDefault"[@@mel.send]
    external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
    external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
    external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
    external target : t -> < .. >  Js.t = "target"[@@mel.get]
    external timeStamp : t -> float = "timeStamp"[@@mel.get]
    external type_ : t -> string = "type"[@@mel.get]
    external persist : t -> unit = "%ignore"
    external propertyName : t -> string = "propertyName"[@@mel.get]
    external pseudoElement : t -> string = "pseudoElement"[@@mel.get]
    external elapsedTime : t -> float = "elapsedTime"[@@mel.get]
  end
end
