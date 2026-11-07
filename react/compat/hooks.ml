[@@@alert "-hook"]

open Melact_runtime

let base : unit Hook.key = Hook.key ()

let run_effect create () =
  match Raw.view (Raw.call0 create) with
  | Callable cleanup -> Some (fun () -> ignore (Raw.call0 cleanup))
  | Missing | Flag _ | Number _ | Text _ | Listed _ | Record _ | Other _ -> None

let effected every listed create deps =
  match Raw.view deps with
  | Listed deps -> listed (Hook.unchecked base) (run_effect create) deps
  | Missing | Flag _ | Number _ | Text _ | Callable _ | Record _ | Other _ -> every (Hook.unchecked base) (run_effect create)

let useEffect create deps = effected React.useEffect React.useEffect1 create deps
let useLayoutEffect create deps = effected React.useLayoutEffect React.useLayoutEffect1 create deps
let useInsertionEffect create deps = effected React.useInsertionEffect React.useInsertionEffect1 create deps

let reduced state action = match Raw.view action with Callable update -> Raw.call1 update state | _ -> action

let useState initial =
  React.useReducerWithMapState (Hook.unchecked base) reduced initial (fun initial ->
      match Raw.view initial with Callable make -> Raw.call0 make | _ -> initial)

let useReducer reducer initial init =
  React.useReducerWithMapState (Hook.unchecked base)
    (fun state action -> Raw.call2 reducer state action)
    initial
    (fun initial -> Option.fold ~none:initial ~some:(fun init -> Raw.call1 init initial) (Raw.present init))

let useMemo compute deps =
  match Raw.view deps with
  | Listed deps -> React.useMemo1 (Hook.unchecked base) (fun () -> Raw.call0 compute) deps
  | _ -> React.useMemo (Hook.unchecked base) (fun () -> Raw.call0 compute)

let useCallback callback deps =
  match Raw.view deps with
  | Listed deps -> React.useCallback1 (Hook.unchecked base) callback deps
  | _ -> React.useCallback (Hook.unchecked base) callback

let useRef initial = React.useRef (Hook.unchecked base) initial
let useContext context = Render.read context
let useId () = React.useId (Hook.unchecked base) ()

let useImperativeHandle reference create deps =
  let run () =
    match Raw.view reference with
    | Callable call ->
        ignore (Raw.call1 call (Raw.call0 create));
        Some (fun () -> ignore (Raw.call1 call Raw.null))
    | Record record ->
        Raw.set record "current" (Raw.call0 create);
        Some (fun () -> Raw.set record "current" Raw.null)
    | Missing | Flag _ | Number _ | Text _ | Listed _ | Other _ -> None
  in
  match Raw.view deps with
  | Listed deps -> React.useLayoutEffect1 (Hook.unchecked base) run (Array.append deps [| reference |])
  | _ -> React.useLayoutEffect (Hook.unchecked base) run

let subscriptions : ((unit -> unit) -> unit -> unit) Raw.table = Raw.table ()

let useSyncExternalStore subscribe snapshot _ =
  let subscribing =
    match Raw.lookup subscriptions subscribe with
    | Some found -> found
    | None ->
        let made notify =
          let unsubscribe = Raw.call1 subscribe (Raw.of_any notify) in
          fun () -> ignore (Raw.call0 unsubscribe)
        in
        Raw.store subscriptions subscribe made;
        made
  in
  React.useSyncExternalStore (Hook.unchecked base) ~subscribe:subscribing ~getSnapshot:(fun () -> Raw.call0 snapshot)

let useDebugValue _ _ = ()
let startTransition run = ignore (Raw.call0 run)
let useTransition () = (false, startTransition)
let useDeferredValue value _ = value
