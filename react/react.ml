open Melhole
open Melact_runtime

type element = View.child

external of_child : View.child -> element = "%identity"
external to_child : element -> View.child = "%identity"
type 'value ref = { mutable current : 'value }
type ('props, 'return) componentLike = 'props -> 'return
type 'props component = ('props, element) componentLike

external component : ('props, element) componentLike -> 'props component = "%identity"

module Context = struct
  type 'value t = Context of 'value Melact_runtime.Context.t [@@unboxed]

  external makeProps : value:'value -> children:element -> unit -> < value : 'value ; children : element > Js.t = ""
  [@@mel.obj]

  let provider (Context context) props = Instance.provide context props##value props##children
end

type ('state, 'action) state = {
  mutable value : 'state;
  mutable rendered : 'state;  (** The value the last render read. *)
  mutable reduce : 'state -> 'action -> 'state;
  dispatch : 'action -> unit;
}

type ('deps, 'value) memo = { mutable inputs : 'deps; mutable result : 'value }

type 'snapshot store = {
  mutable read : unit -> 'snapshot;
  mutable snapshot : 'snapshot;
  mutable subscribe : (unit -> unit) -> unit -> unit;
  mutable unsubscribe : unit -> unit;
}

let reason_react_is_also_in_this_build_remove_it () = ()
let null : element =
  ([%mel.raw {|function (empty) { return Object.assign({ TAG: "React.null" }, empty); }|}] : View.child -> element) View.empty
let string text = View.text text
let int number = View.text (string_of_int number)
let float number = View.text (Js.Float.toString number)
let list elements = View.list elements
let array elements = list (Array.to_list elements)
module Fragment = struct
  external makeProps : children:element -> ?key:string -> unit -> < children : element > Js.t = "" [@@mel.obj]

  let make props = props##children
end

module StrictMode = struct
  external makeProps : children:element -> ?key:string -> unit -> < children : element > Js.t = "" [@@mel.obj]

  let make props = props##children
end

module Suspense = struct
  external makeProps :
    ?children:element -> ?fallback:element -> ?key:string -> unit -> < children : element option ; fallback : element option > Js.t
    = ""
  [@@mel.obj]

  let make props =
    of_child (Instance.suspend ~fallback:(to_child (Option.value ~default:null props##fallback)) (to_child (Option.value ~default:null props##children)))
end

module Children = struct
  let elements child = View.items child
  let map element apply = list (List.map apply (elements element))
  let mapWithIndex element apply = list (List.mapi (fun index item -> apply item index) (elements element))
  let forEach element visit = List.iter visit (elements element)
  let forEachWithIndex element visit = List.iteri (fun index item -> visit item index) (elements element)
  let count element = List.length (elements element)

  let only element =
    match elements element with
    | [ single ] -> single
    | [] | _ :: _ :: _ -> Js.Exn.raiseError "React.Children.only expected to receive a single element"

  let toArray element = Array.of_list (elements element)
end

module Ref = struct
  let current reference = reference.current
  let setCurrent reference value = reference.current <- value
end

let createRef () = { current = Js.Nullable.null }
let isValidElement _ = true

let createElement make props = make props
let createElementVariadic make props children = Melact_runtime.Variadic.with_children children (fun () -> make props)
let jsx make props = make props
let jsxs make props = make props

let jsxKeyed make props ?key () =
  Option.fold ~none:(make props) ~some:(fun key -> of_child (View.with_key key (to_child (make props)))) key

let jsxsKeyed make props ?key () =
  Option.fold ~none:(make props) ~some:(fun key -> of_child (View.with_key key (to_child (make props)))) key

let cloneElement _ _ =
  Js.Exn.raiseError "melact: React.cloneElement is not supported; pass props to the component instead"

let setDisplayName _ _ = ()
let displayName _ = None
let createContext default = Context.Context (Melact_runtime.Context.make default)
let useContext (Context.Context context) = Instance.consume (Instance.current ()) context

let stated cell reduce =
  cell.reduce <- reduce;
  cell.rendered <- cell.value;
  (cell.value, cell.dispatch)

let state_cell instance key reduce initial =
  let bit = Instance.cell_source instance in
  let rec dispatch action =
    let next = cell.reduce cell.value action in
    if not (next == cell.value) then (
      Instance.invalidate_state instance cell
        (fun cell -> match cell.value == cell.rendered with true -> Melhole.View.Unchanged | false -> Melhole.View.Changed)
        bit;
      cell.value <- next)
  and cell = { value = initial; rendered = initial; reduce; dispatch } in
  Instance.put instance key cell;
  cell

let applied state update = update state

let useState key init =
  let instance = Instance.current () in
  stated
    (match Instance.found instance key with Some cell -> cell | None -> state_cell instance key applied (init ()))
    applied

let useReducer key reduce initial =
  let instance = Instance.current () in
  stated (match Instance.found instance key with Some cell -> cell | None -> state_cell instance key reduce initial) reduce

let useReducerWithMapState key reduce initial map =
  let instance = Instance.current () in
  stated
    (match Instance.found instance key with Some cell -> cell | None -> state_cell instance key reduce (map initial))
    reduce

let use_effect timing unchanged key run deps =
  let instance = Instance.current () in
  match Instance.found instance key with
  | Some hook -> (
      match Instance.queued hook with
      | `This_render -> Instance.rerun hook deps run
      | `Earlier -> if not (unchanged (Instance.deps hook) deps) then Instance.rerun hook deps run)
  | None -> Instance.put instance key (Instance.start_effect instance timing deps run)

let memoize unchanged key compute deps =
  let instance = Instance.current () in
  match Instance.found instance key with
  | Some cell ->
      if not (unchanged cell.inputs deps) then (
        cell.inputs <- deps;
        cell.result <- compute ());
      cell.result
  | None ->
      let result = compute () in
      Instance.put instance key { inputs = deps; result };
      result

let remember unchanged key value deps =
  let instance = Instance.current () in
  match Instance.found instance key with
  | Some cell ->
      if not (unchanged cell.inputs deps) then (
        cell.inputs <- deps;
        cell.result <- value);
      cell.result
  | None ->
      Instance.put instance key { inputs = deps; result = value };
      value

let never () () = false
let always () () = true

let same_array a b =
  Array.length a = Array.length b && Array.for_all2 (fun x y -> x == y) a b

let same2 (a, b) (a', b') = a == a' && b == b'
let same3 (a, b, c) (a', b', c') = a == a' && b == b' && c == c'
let same4 (a, b, c, d) (a', b', c', d') = a == a' && b == b' && c == c' && d == d'

let same5 (a, b, c, d, e) (a', b', c', d', e') =
  a == a' && b == b' && c == c' && d == d' && e == e'

let same6 (a, b, c, d, e, f) (a', b', c', d', e', f') =
  a == a' && b == b' && c == c' && d == d' && e == e' && f == f'

let same7 (a, b, c, d, e, f, g) (a', b', c', d', e', f', g') =
  a == a' && b == b' && c == c' && d == d' && e == e' && f == f' && g == g'

let useEffect key run = use_effect Instance.Passive never key run ()
let useEffect0 key run = use_effect Instance.Passive always key run ()
let useEffect1 key run deps = use_effect Instance.Passive same_array key run deps
let useEffect2 key run deps = use_effect Instance.Passive same2 key run deps
let useEffect3 key run deps = use_effect Instance.Passive same3 key run deps
let useEffect4 key run deps = use_effect Instance.Passive same4 key run deps
let useEffect5 key run deps = use_effect Instance.Passive same5 key run deps
let useEffect6 key run deps = use_effect Instance.Passive same6 key run deps
let useEffect7 key run deps = use_effect Instance.Passive same7 key run deps
let useLayoutEffect key run = use_effect Instance.Layout never key run ()
let useLayoutEffect0 key run = use_effect Instance.Layout always key run ()
let useLayoutEffect1 key run deps = use_effect Instance.Layout same_array key run deps
let useLayoutEffect2 key run deps = use_effect Instance.Layout same2 key run deps
let useLayoutEffect3 key run deps = use_effect Instance.Layout same3 key run deps
let useLayoutEffect4 key run deps = use_effect Instance.Layout same4 key run deps
let useLayoutEffect5 key run deps = use_effect Instance.Layout same5 key run deps
let useLayoutEffect6 key run deps = use_effect Instance.Layout same6 key run deps
let useLayoutEffect7 key run deps = use_effect Instance.Layout same7 key run deps
let useMemo key compute = memoize never key compute ()
let useMemo0 key compute = memoize always key compute ()
let useMemo1 key compute deps = memoize same_array key compute deps
let useMemo2 key compute deps = memoize same2 key compute deps
let useMemo3 key compute deps = memoize same3 key compute deps
let useMemo4 key compute deps = memoize same4 key compute deps
let useMemo5 key compute deps = memoize same5 key compute deps
let useMemo6 key compute deps = memoize same6 key compute deps
let useMemo7 key compute deps = memoize same7 key compute deps
let useCallback key fn = remember never key fn ()
let useCallback0 key fn = remember always key fn ()
let useCallback1 key fn deps = remember same_array key fn deps
let useCallback2 key fn deps = remember same2 key fn deps
let useCallback3 key fn deps = remember same3 key fn deps
let useCallback4 key fn deps = remember same4 key fn deps
let useCallback5 key fn deps = remember same5 key fn deps
let useCallback6 key fn deps = remember same6 key fn deps
let useCallback7 key fn deps = remember same7 key fn deps
let useInsertionEffect key run = use_effect Instance.Layout never key run ()
let useInsertionEffect0 key run = use_effect Instance.Layout always key run ()
let useInsertionEffect1 key run deps = use_effect Instance.Layout same_array key run deps
let useInsertionEffect2 key run deps = use_effect Instance.Layout same2 key run deps
let useInsertionEffect3 key run deps = use_effect Instance.Layout same3 key run deps
let useInsertionEffect4 key run deps = use_effect Instance.Layout same4 key run deps
let useInsertionEffect5 key run deps = use_effect Instance.Layout same5 key run deps
let useInsertionEffect6 key run deps = use_effect Instance.Layout same6 key run deps
let useInsertionEffect7 key run deps = use_effect Instance.Layout same7 key run deps

let useSyncExternalStore key ~subscribe ~getSnapshot =
  let instance = Instance.current () in
  let resubscribe cell =
    Instance.after_commit instance Instance.Passive Instance.Run (fun () ->
        cell.unsubscribe ();
        cell.unsubscribe <-
          cell.subscribe (fun () ->
              let next = cell.read () in
              if not (next == cell.snapshot) then (
                cell.snapshot <- next;
                Instance.invalidate instance)))
  in
  let cell =
    Instance.slot instance key (fun () ->
        let cell =
          { read = getSnapshot; snapshot = getSnapshot (); subscribe; unsubscribe = ignore }
        in
        Instance.on_unmount instance (fun () -> cell.unsubscribe ());
        resubscribe cell;
        cell)
  in
  cell.read <- getSnapshot;
  cell.snapshot <- getSnapshot ();
  if not (cell.subscribe == subscribe) then (
    cell.subscribe <- subscribe;
    resubscribe cell);
  cell.snapshot

let useDebugValue _ ?format:_ () = ()
let useRef key initial = Instance.slot (Instance.current ()) key (fun () -> { current = initial })

let imperative unchanged key target make deps =
  use_effect Instance.Layout unchanged key
    (fun () ->
      Option.iter (fun target -> target.current <- make ()) (Js.Nullable.toOption target);
      None)
    deps

let useImperativeHandle0 key target make = imperative always key target make ()
let useImperativeHandle1 key target make deps = imperative same_array key target make deps
let useImperativeHandle2 key target make deps = imperative same2 key target make deps
let useImperativeHandle3 key target make deps = imperative same3 key target make deps
let useImperativeHandle4 key target make deps = imperative same4 key target make deps
let useImperativeHandle5 key target make deps = imperative same5 key target make deps
let useImperativeHandle6 key target make deps = imperative same6 key target make deps
let useImperativeHandle7 key target make deps = imperative same7 key target make deps
let useId key () =
  let instance = Instance.current () in
  Instance.slot instance key (fun () -> Instance.id instance)

let useSyncExternalStoreWithServer key ~subscribe ~getSnapshot ~getServerSnapshot:_ =
  useSyncExternalStore key ~subscribe ~getSnapshot

(** Whether a deferred value's catch-up render is already asked for. *)
type due = Due | Settled

type 'a deferred = { mutable shown : 'a; mutable wanted : 'a; mutable due : due }

let[@warning "-16"] useDeferredValue key value ?initialValue:_ =
  let instance = Instance.current () in
  match Instance.found instance key with
  | None ->
      Instance.put instance key { shown = value; wanted = value; due = Settled };
      value
  | Some cell -> (
      cell.wanted <- value;
      match (Melhole.Dom_api.same cell.shown value, cell.due) with
      | true, _ -> value
      | false, Due -> cell.shown
      | false, Settled ->
          cell.due <- Due;
          Instance.defer (fun () ->
              cell.due <- Settled;
              cell.shown <- cell.wanted;
              Instance.invalidate instance);
          cell.shown)
let startTransition run = run ()
let useTransition () = (false, startTransition)

(** Whether an async action's synchronous part is running, so that an optimistic update belongs to it. *)
type acting = Acting | Idle

(** The pending flag of an async transition hook. *)
type transitions = { mutable pending : bool }

(** An optimistic state: the updates made during async actions still running. *)
type ('state, 'update) optimistic = { mutable updates : 'update list; mutable apply : 'state -> 'update -> 'state }

(** What an action state hook keeps: the state and the action that makes the next one. *)
type ('state, 'data) action_state = { current : 'state; mutable act : 'state -> 'data -> unit }

module Experimental = struct
  type formAction

  external form_action : ('data -> unit) -> formAction = "%identity"

  let in_flight = ref 0
  let acting = ref Idle
  let endings = ref []

  let useContext context = useContext context

  external thenable : 'value Js.Promise.t -> Instance.thenable = "%identity"

  let tracked : 'value Js.Promise.t -> [ `Fulfilled | `Rejected | `Pending ] =
    [%mel.raw
      {|function (promise) {
  if (promise.status === "fulfilled") return "Fulfilled";
  if (promise.status === "rejected") return "Rejected";
  if (promise.status !== "pending") {
    promise.status = "pending";
    promise.then(
      function (value) { if (promise.status === "pending") { promise.status = "fulfilled"; promise.value = value; } },
      function (reason) { if (promise.status === "pending") { promise.status = "rejected"; promise.reason = reason; } });
  }
  return "Pending";
}|}]

  external value : 'value Js.Promise.t -> 'value = "value" [@@mel.get]
  external reason : 'value Js.Promise.t -> Js.Exn.t = "reason" [@@mel.get]

  let usePromise promise =
    match tracked promise with
    | `Fulfilled -> value promise
    | `Rejected -> ([%mel.raw "function (reason) { throw reason }"] : Js.Exn.t -> 'value) (reason promise)
    | `Pending -> raise (Instance.Suspended (thenable promise))

  let awaited = ref None

  let promise child =
    let definition =
      match !awaited with
      | Some definition -> definition
      | None ->
          let made = Component.make ~name:"React.Experimental.promise" in
          awaited := Some made;
          made
    in
    Instance.component definition [| View.Input child |] (fun () -> usePromise child)

  let useTransitionAsync key () =
    let instance = Instance.current () in
    let cell = Instance.slot instance key (fun () -> { pending = false }) in
    ( cell.pending,
      fun run ->
        incr in_flight;
        (match cell.pending with
        | true -> ()
        | false ->
            cell.pending <- true;
            endings := (fun () -> cell.pending <- false; Instance.invalidate instance) :: !endings);
        Instance.invalidate instance;
        let saved = !acting in
        acting := Acting;
        let promise = match run () with promise -> acting := saved; promise | exception error -> acting := saved; raise error in
        Js.Promise.then_
          (fun () ->
            decr in_flight;
            (match !in_flight with
            | 0 ->
                let ended = !endings in
                endings := [];
                List.iter (fun ending -> ending ()) ended
            | _ -> ());
            Js.Promise.resolve ())
          promise )

  let useOptimistic key state apply =
    let instance = Instance.current () in
    let cell = Instance.slot instance key (fun () -> { updates = []; apply }) in
    cell.apply <- apply;
    ( List.fold_left cell.apply state cell.updates,
      fun update ->
        match !acting with
        | Idle -> ()
        | Acting ->
            (match cell.updates with
            | [] -> endings := (fun () -> cell.updates <- []; Instance.invalidate instance) :: !endings
            | _ :: _ -> ());
            cell.updates <- cell.updates @ [ update ];
            Instance.invalidate instance )

  let useActionState key act initial ?permalink:_ () =
    let instance = Instance.current () in
    let cell = Instance.slot instance key (fun () -> { current = initial; act }) in
    cell.act <- act;
    (cell.current, form_action (fun data -> cell.act cell.current data), false)
end

let useTransitionAsync () =
  ( false,
    fun run ->
      run ();
      Js.Promise.resolve () )
let act run =
  run ();
  Instance.flush ();
  let rec caught_up () = match Instance.run_deferred () with `Ran -> Instance.flush (); caught_up () | `Idle -> () in
  caught_up ();
  View.restore_controlled ();
  Js.Promise.resolve ()

let actAsync run =
  Js.Promise.then_
    (fun () ->
      Instance.flush ();
      let rec caught_up () = match Instance.run_deferred () with `Ran -> Instance.flush (); caught_up () | `Idle -> () in
      caught_up ();
      View.restore_controlled ();
      Js.Promise.resolve ())
    (run ())

let forwardRef render props = render props Js.Nullable.null
let memo component = component
let memoCustomCompareProps component _ = component

module Event = struct
  include Melact_event
end
