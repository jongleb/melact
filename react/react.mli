(** reason-react's [React] module for melact. Every hook that keeps state
    takes the key of its call site first; melact-ppx inserts it, so source
    code calls [React.useState init] exactly as with reason-react. *)

(** A piece of UI. *)
type element = Element of Melact_view.View.child [@@unboxed]

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
  type 'value t = Context of 'value Melact_view.Context.t [@@unboxed]

  val provider : 'value t -> value:'value -> children:element -> unit -> element
end

val createContext : 'value -> 'value Context.t
val useContext : 'value Context.t -> 'value

(** The slot of a [useState] or [useReducer] call. *)
type ('state, 'action) state

(** The slot of an effect, with the dependencies it last ran with. *)
type 'deps effect_cell

(** The slot of a memo, with its dependencies and value. *)
type ('deps, 'value) memo

val useState :
  ('state, 'state -> 'state) state Melact_view.Hook.key ->
  (unit -> 'state) ->
  'state * (('state -> 'state) -> unit)

val useReducer :
  ('state, 'action) state Melact_view.Hook.key ->
  ('state -> 'action -> 'state) ->
  'state ->
  'state * ('action -> unit)

val useReducerWithMapState :
  ('state, 'action) state Melact_view.Hook.key ->
  ('state -> 'action -> 'state) ->
  'initial ->
  ('initial -> 'state) ->
  'state * ('action -> unit)

val useEffect :
  unit effect_cell Melact_view.Hook.key -> (unit -> (unit -> unit) option) -> unit

val useEffect0 :
  unit effect_cell Melact_view.Hook.key -> (unit -> (unit -> unit) option) -> unit

val useEffect1 :
  'a array effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a array ->
  unit

val useEffect2 :
  ('a * 'b) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b ->
  unit

val useEffect3 :
  ('a * 'b * 'c) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c ->
  unit

val useEffect4 :
  ('a * 'b * 'c * 'd) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd ->
  unit

val useEffect5 :
  ('a * 'b * 'c * 'd * 'e) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e ->
  unit

val useEffect6 :
  ('a * 'b * 'c * 'd * 'e * 'f) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit

val useEffect7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit

val useLayoutEffect :
  unit effect_cell Melact_view.Hook.key -> (unit -> (unit -> unit) option) -> unit

val useLayoutEffect0 :
  unit effect_cell Melact_view.Hook.key -> (unit -> (unit -> unit) option) -> unit

val useLayoutEffect1 :
  'a array effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a array ->
  unit

val useLayoutEffect2 :
  ('a * 'b) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b ->
  unit

val useLayoutEffect3 :
  ('a * 'b * 'c) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c ->
  unit

val useLayoutEffect4 :
  ('a * 'b * 'c * 'd) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd ->
  unit

val useLayoutEffect5 :
  ('a * 'b * 'c * 'd * 'e) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e ->
  unit

val useLayoutEffect6 :
  ('a * 'b * 'c * 'd * 'e * 'f) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit

val useLayoutEffect7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g) effect_cell Melact_view.Hook.key ->
  (unit -> (unit -> unit) option) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit

val useMemo : (unit, 'value) memo Melact_view.Hook.key -> (unit -> 'value) -> 'value
val useMemo0 : (unit, 'value) memo Melact_view.Hook.key -> (unit -> 'value) -> 'value

val useMemo1 :
  ('a array, 'value) memo Melact_view.Hook.key -> (unit -> 'value) -> 'a array -> 'value

val useMemo2 :
  ('a * 'b, 'value) memo Melact_view.Hook.key -> (unit -> 'value) -> 'a * 'b -> 'value

val useMemo3 :
  ('a * 'b * 'c, 'value) memo Melact_view.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c ->
  'value

val useMemo4 :
  ('a * 'b * 'c * 'd, 'value) memo Melact_view.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd ->
  'value

val useMemo5 :
  ('a * 'b * 'c * 'd * 'e, 'value) memo Melact_view.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e ->
  'value

val useMemo6 :
  ('a * 'b * 'c * 'd * 'e * 'f, 'value) memo Melact_view.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  'value

val useMemo7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g, 'value) memo Melact_view.Hook.key ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  'value

val useCallback : (unit, 'fn) memo Melact_view.Hook.key -> 'fn -> 'fn
val useCallback0 : (unit, 'fn) memo Melact_view.Hook.key -> 'fn -> 'fn
val useCallback1 : ('a array, 'fn) memo Melact_view.Hook.key -> 'fn -> 'a array -> 'fn
val useCallback2 : ('a * 'b, 'fn) memo Melact_view.Hook.key -> 'fn -> 'a * 'b -> 'fn

val useCallback3 :
  ('a * 'b * 'c, 'fn) memo Melact_view.Hook.key -> 'fn -> 'a * 'b * 'c -> 'fn

val useCallback4 :
  ('a * 'b * 'c * 'd, 'fn) memo Melact_view.Hook.key -> 'fn -> 'a * 'b * 'c * 'd -> 'fn

val useCallback5 :
  ('a * 'b * 'c * 'd * 'e, 'fn) memo Melact_view.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e ->
  'fn

val useCallback6 :
  ('a * 'b * 'c * 'd * 'e * 'f, 'fn) memo Melact_view.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  'fn

val useCallback7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g, 'fn) memo Melact_view.Hook.key ->
  'fn ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  'fn

val useRef : 'value ref Melact_view.Hook.key -> 'value -> 'value ref

val useImperativeHandle0 :
  unit effect_cell Melact_view.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  unit

val useImperativeHandle1 :
  'a array effect_cell Melact_view.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a array ->
  unit

val useImperativeHandle2 :
  ('a * 'b) effect_cell Melact_view.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b ->
  unit

val useImperativeHandle3 :
  ('a * 'b * 'c) effect_cell Melact_view.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c ->
  unit

val useImperativeHandle4 :
  ('a * 'b * 'c * 'd) effect_cell Melact_view.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd ->
  unit

val useImperativeHandle5 :
  ('a * 'b * 'c * 'd * 'e) effect_cell Melact_view.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e ->
  unit

val useImperativeHandle6 :
  ('a * 'b * 'c * 'd * 'e * 'f) effect_cell Melact_view.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f ->
  unit

val useImperativeHandle7 :
  ('a * 'b * 'c * 'd * 'e * 'f * 'g) effect_cell Melact_view.Hook.key ->
  'value ref Js.Nullable.t ->
  (unit -> 'value) ->
  'a * 'b * 'c * 'd * 'e * 'f * 'g ->
  unit

val useId : string Melact_view.Hook.key -> unit -> string
val useTransition : unit -> bool * ((unit -> unit) -> unit)
val startTransition : (unit -> unit) -> unit
val memo : ('props -> element) -> 'props -> element

val memoCustomCompareProps :
  ('props -> element) -> ('props -> 'props -> bool) -> 'props -> element
