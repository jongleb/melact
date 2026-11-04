open Melhole

type element = Element of View.child [@@unboxed]
type 'value ref = { mutable current : 'value }

module Context = struct
  type 'value t = Context of 'value Melhole.Context.t [@@unboxed]

  let provider (Context context) ~value ~children:(Element children) () =
    Element (View.provide context value children)
end

type ('state, 'action) state = {
  mutable value : 'state;
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

let null = Element View.empty
let string text = Element (View.text text)
let int number = Element (View.text (string_of_int number))
let float number = Element (View.text (Js.Float.toString number))
let list elements = Element (View.list (List.map (fun (Element child) -> child) elements))
let array elements = list (Array.to_list elements)
module Fragment = struct
  let make ~children () = children
end

module StrictMode = struct
  let make ~children () = children
end

module Suspense = struct
  let make ?fallback:_ ~children () = children
end

module Children = struct
  let elements (Element child) = List.map (fun item -> Element item) (View.items child)
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

let cloneElement _ _ =
  Js.Exn.raiseError "melact: React.cloneElement is not supported; pass props to the component instead"

let setDisplayName _ _ = ()
let displayName _ = None
let createContext default = Context.Context (Melhole.Context.make default)
let useContext (Context.Context context) = View.consume (View.current ()) context

let reducer key reduce initial =
  let instance = View.current () in
  let cell =
    View.slot instance key (fun () ->
        let initial = initial () in
        let rec cell =
          {
            value = initial;
            reduce;
            dispatch =
              (fun action ->
                let next = cell.reduce cell.value action in
                if not (next == cell.value) then (
                  View.invalidate instance;
                  cell.value <- next));
          }
        in
        cell)
  in
  cell.reduce <- reduce;
  (cell.value, cell.dispatch)

let useState key init = reducer key (fun state update -> update state) init
let useReducer key reduce initial = reducer key reduce (fun () -> initial)

let useReducerWithMapState key reduce initial map =
  reducer key reduce (fun () -> map initial)

let use_effect timing unchanged key run deps =
  let instance = View.current () in
  let schedule cell =
    View.after_commit instance timing Cleanup (fun () ->
        Option.iter (fun cleanup -> cleanup ()) cell.cleanup;
        cell.cleanup <- None);
    View.after_commit instance timing Run (fun () -> cell.cleanup <- run ())
  in
  let cell =
    View.slot instance key (fun () ->
        let cell = { deps; cleanup = None } in
        View.on_unmount instance (fun () ->
            Option.iter (fun cleanup -> cleanup ()) cell.cleanup;
            cell.cleanup <- None);
        schedule cell;
        cell)
  in
  if not (unchanged cell.deps deps) then (
    cell.deps <- deps;
    schedule cell)

let memoize unchanged key compute deps =
  let cell =
    View.slot (View.current ()) key (fun () -> { inputs = deps; result = compute () })
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

let useEffect key run = use_effect Passive never key run ()
let useEffect0 key run = use_effect Passive always key run ()
let useEffect1 key run deps = use_effect Passive same_array key run deps
let useEffect2 key run deps = use_effect Passive same2 key run deps
let useEffect3 key run deps = use_effect Passive same3 key run deps
let useEffect4 key run deps = use_effect Passive same4 key run deps
let useEffect5 key run deps = use_effect Passive same5 key run deps
let useEffect6 key run deps = use_effect Passive same6 key run deps
let useEffect7 key run deps = use_effect Passive same7 key run deps
let useLayoutEffect key run = use_effect Layout never key run ()
let useLayoutEffect0 key run = use_effect Layout always key run ()
let useLayoutEffect1 key run deps = use_effect Layout same_array key run deps
let useLayoutEffect2 key run deps = use_effect Layout same2 key run deps
let useLayoutEffect3 key run deps = use_effect Layout same3 key run deps
let useLayoutEffect4 key run deps = use_effect Layout same4 key run deps
let useLayoutEffect5 key run deps = use_effect Layout same5 key run deps
let useLayoutEffect6 key run deps = use_effect Layout same6 key run deps
let useLayoutEffect7 key run deps = use_effect Layout same7 key run deps
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
let useInsertionEffect key run = use_effect Layout never key run ()
let useInsertionEffect0 key run = use_effect Layout always key run ()
let useInsertionEffect1 key run deps = use_effect Layout same_array key run deps
let useInsertionEffect2 key run deps = use_effect Layout same2 key run deps
let useInsertionEffect3 key run deps = use_effect Layout same3 key run deps

let useSyncExternalStore key ~subscribe ~getSnapshot =
  let instance = View.current () in
  let resubscribe cell =
    View.after_commit instance Passive Run (fun () ->
        cell.unsubscribe ();
        cell.unsubscribe <-
          cell.subscribe (fun () ->
              let next = cell.read () in
              if not (next == cell.snapshot) then (
                cell.snapshot <- next;
                View.invalidate instance)))
  in
  let cell =
    View.slot instance key (fun () ->
        let cell =
          { read = getSnapshot; snapshot = getSnapshot (); subscribe; unsubscribe = ignore }
        in
        View.on_unmount instance (fun () -> cell.unsubscribe ());
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
let useRef key initial = View.slot (View.current ()) key (fun () -> { current = initial })

let imperative unchanged key target make deps =
  use_effect Layout unchanged key
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
  View.slot (View.current ()) key (fun () ->
      incr ids;
      ":m" ^ string_of_int !ids ^ ":")

let startTransition run = run ()
let useTransition () = (false, startTransition)
let act run =
  run ();
  View.flush ();
  Js.Promise.resolve ()

let actAsync run =
  Js.Promise.then_
    (fun () ->
      View.flush ();
      Js.Promise.resolve ())
    (run ())

let forwardRef render props = render props Js.Nullable.null
let memo component props = component props
let memoCustomCompareProps component _ props = component props
