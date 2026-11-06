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

type 'deps effect_cell = { mutable deps : 'deps; mutable cleanup : (unit -> unit) option }
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

let reducer key reduce initial =
  let instance = Instance.current () in
  let cell =
    Instance.slot instance key (fun () ->
        let initial = initial () in
        let rec cell =
          {
            value = initial;
            rendered = initial;
            reduce;
            dispatch =
              (fun action ->
                let next = cell.reduce cell.value action in
                if not (next == cell.value) then (
                  Instance.invalidate_state instance check;
                  cell.value <- next));
          }
        and check () = match cell.value == cell.rendered with true -> Melhole.View.Unchanged | false -> Melhole.View.Changed in
        cell)
  in
  cell.reduce <- reduce;
  cell.rendered <- cell.value;
  (cell.value, cell.dispatch)

let useState key init = reducer key (fun state update -> update state) init
let useReducer key reduce initial = reducer key reduce (fun () -> initial)

let useReducerWithMapState key reduce initial map =
  reducer key reduce (fun () -> map initial)

let use_effect timing unchanged key run deps =
  let instance = Instance.current () in
  let schedule cell =
    Instance.after_commit instance timing Instance.Cleanup (fun () ->
        Option.iter (fun cleanup -> cleanup ()) cell.cleanup;
        cell.cleanup <- None);
    Instance.after_commit instance timing Instance.Run (fun () -> cell.cleanup <- run ())
  in
  let made = ref `Kept in
  let cell =
    Instance.slot instance key (fun () ->
        let cell = { deps; cleanup = None } in
        Instance.on_unmount instance (fun () ->
            Option.iter (fun cleanup -> cleanup ()) cell.cleanup;
            cell.cleanup <- None);
        made := `Made;
        cell)
  in
  match !made with
  | `Made -> schedule cell
  | `Kept ->
      if not (unchanged cell.deps deps) then (
        cell.deps <- deps;
        schedule cell)

let memoize unchanged key compute deps =
  let cell =
    Instance.slot (Instance.current ()) key (fun () -> { inputs = deps; result = compute () })
  in
  if not (unchanged cell.inputs deps) then (
    cell.inputs <- deps;
    cell.result <- compute ());
  cell.result

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
let useCallback key fn = memoize never key (fun () -> fn) ()
let useCallback0 key fn = memoize always key (fun () -> fn) ()
let useCallback1 key fn deps = memoize same_array key (fun () -> fn) deps
let useCallback2 key fn deps = memoize same2 key (fun () -> fn) deps
let useCallback3 key fn deps = memoize same3 key (fun () -> fn) deps
let useCallback4 key fn deps = memoize same4 key (fun () -> fn) deps
let useCallback5 key fn deps = memoize same5 key (fun () -> fn) deps
let useCallback6 key fn deps = memoize same6 key (fun () -> fn) deps
let useCallback7 key fn deps = memoize same7 key (fun () -> fn) deps
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
let ids = ref 0

let useId key () =
  Instance.slot (Instance.current ()) key (fun () ->
      incr ids;
      ":m" ^ string_of_int !ids ^ ":")

let useSyncExternalStoreWithServer key ~subscribe ~getSnapshot ~getServerSnapshot:_ =
  useSyncExternalStore key ~subscribe ~getSnapshot

let[@warning "-16"] useDeferredValue value ?initialValue:_ = value
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
  View.restore_controlled ();
  Js.Promise.resolve ()

let actAsync run =
  Js.Promise.then_
    (fun () ->
      Instance.flush ();
      View.restore_controlled ();
      Js.Promise.resolve ())
    (run ())

let forwardRef render props = render props Js.Nullable.null
let memo component = component
let memoCustomCompareProps component _ = component

module Event =
struct
  type 'a synthetic
  external ofNative : Dom.event -> 'a synthetic = "%identity"
  module Synthetic =
  struct
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
  module Clipboard =
  struct
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
  module Composition =
  struct
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
  module Drag =
  struct
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
  module Keyboard =
  struct
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
  module Focus =
  struct
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
  module Form =
  struct
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
  module Mouse =
  struct
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
  module Pointer =
  struct
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
  module Selection =
  struct
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
  module Touch =
  struct
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
  module UI =
  struct
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
  module Wheel =
  struct
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
  module Media =
  struct
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
  module Image =
  struct
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
  module Animation =
  struct
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
  module Transition =
  struct
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
