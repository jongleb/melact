(** reason-react's [React] module for Melact's server build ([melact-ppx -server]): components
    render once, when their HTML is written, with their hooks' initial values; effects never run.
    Every hook takes the key of its call site first; melact-ppx inserts it, so source code calls
    [React.useState init] exactly as with reason-react. *)

(** A piece of UI. *)
type element

external of_child : Melhole_server.child -> element = "%identity"
external to_child : element -> Melhole_server.child = "%identity"

(** Called once by every file melact-ppx compiles. reason-react's [React] has no such value, so a
    build where its [React] shadows Melact's fails to compile, or, if only the JavaScript import went
    to reason-react's file, fails as the module loads, with this name in the message. *)
val reason_react_is_also_in_this_build_remove_it : unit -> unit

val null : element
val string : string -> element
val int : int -> element
val float : float -> element
val array : element array -> element
val list : element list -> element

(** A mutable box that survives renders. *)
type 'value ref = { mutable current : 'value }

(** What renders ['props] into ['return]; reason-react's own shape, so plain functions are components. *)
type ('props, 'return) componentLike = 'props -> 'return

(** A component: a function of its props. [[@react.component]] gives every component its own
    abstract [props], built by [makeProps]. *)
type 'props component = ('props, element) componentLike

external component : ('props, element) componentLike -> 'props component = "%identity"

module Context : sig
  (** A value passed down to every component below its provider. *)
  type 'value t = Context of 'value Melact_server.Context.t [@@unboxed]

  external makeProps : value:'value -> children:element -> unit -> < value : 'value ; children : element > Js.t = ""
  [@@mel.obj]

  val provider : 'value t -> < value : 'value ; children : element > Js.t component
end

module Fragment : sig
  external makeProps : children:element -> ?key:string -> unit -> < children : element > Js.t = "" [@@mel.obj]

  val make : < children : element > Js.t component
end

module StrictMode : sig
  external makeProps : children:element -> ?key:string -> unit -> < children : element > Js.t = "" [@@mel.obj]

  val make : < children : element > Js.t component
end

module Suspense : sig
  external makeProps :
    ?children:element -> ?fallback:element -> ?key:string -> unit -> < children : element option ; fallback : element option > Js.t
    = ""
  [@@mel.obj]

  val make : < children : element option ; fallback : element option > Js.t component
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
val createElement : 'props component -> 'props -> element

(** [createElement] with children: a DOM element from [ReactDOM.stringToComponent] gets them as its
    children; a component gets the props it was given. *)
val createElementVariadic : 'props component -> 'props -> element array -> element

val jsx : 'props component -> 'props -> element
val jsxs : 'props component -> 'props -> element
val jsxKeyed : 'props component -> 'props -> ?key:string -> unit -> element
val jsxsKeyed : 'props component -> 'props -> ?key:string -> unit -> element

(** Fails, as on the client: pass props to the component instead. *)
val cloneElement : element -> 'props -> element
val setDisplayName : ('props -> element) -> string -> unit
val displayName : ('props -> element) -> string option
val createContext : 'value -> 'value Context.t
val useContext : 'value Context.t -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useState :
  ('state, 'state -> 'state) Melact_server.Component.state Melact_server.Hook.key ->
  (unit -> 'state) ->
  'state * (('state -> 'state) -> unit)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useReducer :
  ('state, 'action) Melact_server.Component.state Melact_server.Hook.key ->
  ('state -> 'action -> 'state) ->
  'state ->
  'state * ('action -> unit)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useReducerWithMapState :
  ('state, 'action) Melact_server.Component.state Melact_server.Hook.key ->
  ('state -> 'action -> 'state) ->
  'initial ->
  ('initial -> 'state) ->
  'state * ('action -> unit)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect :
  unit Melact_server.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect0 :
  unit Melact_server.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect1 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a array ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect2 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect3 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect4 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect5 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect6 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useEffect7 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect :
  unit Melact_server.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect0 :
  unit Melact_server.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect1 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a array ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect2 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect3 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect4 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect5 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect6 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useLayoutEffect7 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo : (unit, 'value) Melact_server.Component.memo Melact_server.Hook.key -> (unit -> 'value) -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useMemo0 : (unit, 'value) Melact_server.Component.memo Melact_server.Hook.key -> (unit -> 'value) -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo1 :
  ('a array, 'value) Melact_server.Component.memo Melact_server.Hook.key -> (unit -> 'value) -> 'a array -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo2 :
  ('a * 'b, 'value) Melact_server.Component.memo Melact_server.Hook.key -> (unit -> 'value) -> 'a * 'b -> 'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo3 :
  ('a * 'b * 'c, 'value) Melact_server.Component.memo Melact_server.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo4 :
  ('a * 'b * 'c * 'd, 'value) Melact_server.Component.memo Melact_server.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo5 :
  ('a * 'b * 'c * 'd * 'e, 'value) Melact_server.Component.memo Melact_server.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo6 :
  ('a * 'b * 'c * 'd * 'e * 'f, 'value) Melact_server.Component.memo Melact_server.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useMemo7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g, 'value) Melact_server.Component.memo Melact_server.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  'value
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback : (unit, 'fn) Melact_server.Component.memo Melact_server.Hook.key -> 'fn -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useCallback0 : (unit, 'fn) Melact_server.Component.memo Melact_server.Hook.key -> 'fn -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useCallback1 : ('a array, 'fn) Melact_server.Component.memo Melact_server.Hook.key -> 'fn -> 'a array -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useCallback2 : ('a * 'b, 'fn) Melact_server.Component.memo Melact_server.Hook.key -> 'fn -> 'a * 'b -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback3 :
  ('a * 'b * 'c, 'fn) Melact_server.Component.memo Melact_server.Hook.key -> 'fn -> 'a * 'b * 'c -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback4 :
  ('a * 'b * 'c * 'd, 'fn) Melact_server.Component.memo Melact_server.Hook.key -> 'fn -> 'a * 'b * 'c * 'd -> 'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback5 :
  ('a * 'b * 'c * 'd * 'e, 'fn) Melact_server.Component.memo Melact_server.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e ->
  'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback6 :
  ('a * 'b * 'c * 'd * 'e * 'f, 'fn) Melact_server.Component.memo Melact_server.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useCallback7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g, 'fn) Melact_server.Component.memo Melact_server.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  'fn
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useRef : 'value ref Melact_server.Hook.key -> 'value -> 'value ref
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect :
  unit Melact_server.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect0 :
  unit Melact_server.Hook.key -> (unit -> (unit -> unit) option) -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect1 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a array ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect2 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect3 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect4 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect5 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect6 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useInsertionEffect7 :
  unit Melact_server.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

(** React's server needs a server snapshot: without one the render fails, as React's does. *)
val useSyncExternalStore :
  unit Melact_server.Hook.key ->
  subscribe:((unit -> unit) -> unit -> unit) ->
  getSnapshot:(unit -> 'snapshot) ->
  'snapshot
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

(** The server snapshot. *)
val useSyncExternalStoreWithServer :
  unit Melact_server.Hook.key ->
  subscribe:((unit -> unit) -> unit -> unit) ->
  getSnapshot:(unit -> 'snapshot) ->
  getServerSnapshot:(unit -> 'snapshot) ->
  'snapshot
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

(** The value itself, as on React's server. *)
val useDeferredValue : 'a -> ?initialValue:'a -> 'a
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useDebugValue : 'value -> ?format:('value -> string) -> unit -> unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle0 :
  unit Melact_server.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle1 :
  unit Melact_server.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a array ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle2 :
  unit Melact_server.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle3 :
  unit Melact_server.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle4 :
  unit Melact_server.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle5 :
  unit Melact_server.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle6 :
  unit Melact_server.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useImperativeHandle7 :
  unit Melact_server.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

(** React's server id: [:R], the tree id of the component's position, for the second and later ids of
    a component [H] and their number, in base 32, and [:]. Hydration takes the same ids. *)
val useId : unit Melact_server.Hook.key -> unit -> string
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
val useTransition : unit -> bool * ((unit -> unit) -> unit)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

val useTransitionAsync : unit -> bool * ((unit -> unit) -> unit Js.Promise.t)
[@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

(** React 19's APIs, as reason-react 0.17 declares them. *)
module Experimental : sig
  (** What [useActionState] gives for a form's action. *)
  type formAction

  (** A promise as an element: on the server it suspends, and the nearest Suspense boundary is left
      for the client, as React's [renderToString] leaves it. *)
  val promise : element Js.Promise.t -> element

  (** React's [use] of a promise: on the server it suspends, as [promise] does. *)
  val usePromise : 'value Js.Promise.t -> 'value

  val useContext : 'value Context.t -> 'value
  [@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

  (** Not pending, and [start] runs the action, as no event happens on the server. *)
  val useTransitionAsync :
    unit Melact_server.Hook.key -> unit -> bool * ((unit -> unit Js.Promise.t) -> unit Js.Promise.t)
  [@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

  (** The state itself: no action runs on the server. *)
  val useOptimistic :
    unit Melact_server.Hook.key ->
    'state ->
    ('state -> 'update -> 'state) ->
    'state * ('update -> unit)
  [@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]

  (** As reason-react declares it, the action returns nothing and [formAction] cannot be given to a
      [form]: the state stays the initial one. *)
  val useActionState :
    unit Melact_server.Hook.key ->
    ('state -> Js.FormData.t -> unit) ->
    'state ->
    ?permalink:bool ->
    unit ->
    'state * formAction * bool
  [@@alert hook "React calls hooks in the same order on every render: call them at the top level of a component, not in a branch, a loop or a callback"]
end

val startTransition : (unit -> unit) -> unit
val act : (unit -> unit) -> unit Js.Promise.t
val actAsync : (unit -> unit Js.Promise.t) -> unit Js.Promise.t
val forwardRef : ('props -> 'value ref Js.Nullable.t -> element) -> 'props component
val memo : 'props component -> 'props component
val memoCustomCompareProps : 'props component -> ('props -> 'props -> bool) -> 'props component

(** React's synthetic events, as reason-react declares them: typed on the server, never fired. *)
module Event : module type of struct
  include Melact_event
end
