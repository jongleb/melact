type element = Element of Melhole_server.child [@@unboxed]

external of_child : Melhole_server.child -> element = "%identity"
external to_child : element -> Melhole_server.child = "%identity"

type 'value ref = { mutable current : 'value }
type ('props, 'return) componentLike = 'props -> 'return
type 'props component = ('props, element) componentLike

external component : ('props, element) componentLike -> 'props component = "%identity"

module Context = struct
  type 'value t = Context of 'value Melact_server.Context.t [@@unboxed]
  type 'value props = { value : 'value; children : element }

  let makeProps ~value ~children () = { value; children }
  let provider (Context context) props = Element (Melact_server.Context.provide context props.value (to_child props.children))
end

let reason_react_is_also_in_this_build_remove_it () = ()
let null = Element Melhole_server.empty
let string text = Element (Melhole_server.text text)
let int number = Element (Melhole_server.text (string_of_int number))
let float number = Element (Melhole_server.text (Melhole_server.float number))
let array elements = Element (Melhole_server.array (Array.map to_child elements))
let list elements = array (Array.of_list elements)

module Fragment = struct
  type props = { children : element }

  let makeProps ~children ?key:_ () = { children }
  let make props = props.children
end

module StrictMode = struct
  type props = { children : element }

  let makeProps ~children ?key:_ () = { children }
  let make props = props.children
end

module Suspense = struct
  type props = { children : element option; fallback : element option }

  let makeProps ?children ?fallback ?key:_ () = { children; fallback }

  let make props =
    Element
      (Melact_server.Suspense.boundary
         ~fallback:(to_child (Option.value ~default:null props.fallback))
         (to_child (Option.value ~default:null props.children)))
end

module Children = struct
  let elements element = List.map of_child (Melhole_server.items (to_child element))
  let map element apply = list (List.map apply (elements element))
  let mapWithIndex element apply = list (List.mapi (fun index item -> apply item index) (elements element))
  let forEach element visit = List.iter visit (elements element)
  let forEachWithIndex element visit = List.iteri (fun index item -> visit item index) (elements element)
  let count element = List.length (elements element)

  let only element =
    match elements element with
    | [ single ] -> single
    | [] | _ :: _ :: _ -> failwith "React.Children.only expected to receive a single element"

  let toArray element = Array.of_list (elements element)
end

module Ref = struct
  let current reference = reference.current
  let setCurrent reference value = reference.current <- value
end

let createRef () = { current = None }
let isValidElement _ = true
let createElement make props = make props
let createElementVariadic make props children = Melact_server.Variadic.with_children (Array.map to_child children) (fun () -> make props)
let jsx make props = make props
let jsxs make props = make props
let jsxKeyed make props ?key:_ () = make props
let jsxsKeyed make props ?key:_ () = make props

let cloneElement _ _ =
  failwith "melact: React.cloneElement is not supported; pass props to the component instead"

let setDisplayName _ _ = ()
let displayName _ = None
let createContext default = Context.Context (Melact_server.Context.make default)
let useContext (Context.Context context) = Melact_server.Context.read context
let useState key init = Melact_server.Component.state key (fun state update -> update state) init
let useReducer key reduce initial = Melact_server.Component.state key reduce (fun () -> initial)
let useReducerWithMapState key reduce initial map = Melact_server.Component.state key reduce (fun () -> map initial)
let useEffect _ _ = ()
let useEffect0 _ _ = ()
let useEffect1 _ _ _ = ()
let useEffect2 _ _ _ = ()
let useEffect3 _ _ _ = ()
let useEffect4 _ _ _ = ()
let useEffect5 _ _ _ = ()
let useEffect6 _ _ _ = ()
let useEffect7 _ _ _ = ()
let useLayoutEffect _ _ = ()
let useLayoutEffect0 _ _ = ()
let useLayoutEffect1 _ _ _ = ()
let useLayoutEffect2 _ _ _ = ()
let useLayoutEffect3 _ _ _ = ()
let useLayoutEffect4 _ _ _ = ()
let useLayoutEffect5 _ _ _ = ()
let useLayoutEffect6 _ _ _ = ()
let useLayoutEffect7 _ _ _ = ()
let useInsertionEffect _ _ = ()
let useInsertionEffect0 _ _ = ()
let useInsertionEffect1 _ _ _ = ()
let useInsertionEffect2 _ _ _ = ()
let useInsertionEffect3 _ _ _ = ()
let useInsertionEffect4 _ _ _ = ()
let useInsertionEffect5 _ _ _ = ()
let useInsertionEffect6 _ _ _ = ()
let useInsertionEffect7 _ _ _ = ()
let useMemo key compute = Melact_server.Component.memo key Melact_server.Deps.always () compute
let useMemo0 key compute = Melact_server.Component.memo key Melact_server.Deps.never () compute
let useMemo1 key compute deps = Melact_server.Component.memo key Melact_server.Deps.array deps compute
let useMemo2 key compute deps = Melact_server.Component.memo key Melact_server.Deps.two deps compute
let useMemo3 key compute deps = Melact_server.Component.memo key Melact_server.Deps.three deps compute
let useMemo4 key compute deps = Melact_server.Component.memo key Melact_server.Deps.four deps compute
let useMemo5 key compute deps = Melact_server.Component.memo key Melact_server.Deps.five deps compute
let useMemo6 key compute deps = Melact_server.Component.memo key Melact_server.Deps.six deps compute
let useMemo7 key compute deps = Melact_server.Component.memo key Melact_server.Deps.seven deps compute
let useCallback key fn = Melact_server.Component.memo key Melact_server.Deps.always () (fun () -> fn)
let useCallback0 key fn = Melact_server.Component.memo key Melact_server.Deps.never () (fun () -> fn)
let useCallback1 key fn deps = Melact_server.Component.memo key Melact_server.Deps.array deps (fun () -> fn)
let useCallback2 key fn deps = Melact_server.Component.memo key Melact_server.Deps.two deps (fun () -> fn)
let useCallback3 key fn deps = Melact_server.Component.memo key Melact_server.Deps.three deps (fun () -> fn)
let useCallback4 key fn deps = Melact_server.Component.memo key Melact_server.Deps.four deps (fun () -> fn)
let useCallback5 key fn deps = Melact_server.Component.memo key Melact_server.Deps.five deps (fun () -> fn)
let useCallback6 key fn deps = Melact_server.Component.memo key Melact_server.Deps.six deps (fun () -> fn)
let useCallback7 key fn deps = Melact_server.Component.memo key Melact_server.Deps.seven deps (fun () -> fn)
let useRef key initial = Melact_server.Component.take (Melact_server.Component.current ()) key (fun () -> { current = initial })

let useSyncExternalStore _ ~subscribe:_ ~getSnapshot:_ =
  failwith
    "Missing getServerSnapshot, which is required for server-rendered content. Will revert to client rendering."

let useSyncExternalStoreWithServer _ ~subscribe:_ ~getSnapshot:_ ~getServerSnapshot = getServerSnapshot ()
let[@warning "-16"] useDeferredValue (_ : unit Melact_server.Hook.key) value ?initialValue:_ = value
let useDebugValue _ ?format:_ () = ()
let useImperativeHandle0 _ _ _ = ()
let useImperativeHandle1 _ _ _ _ = ()
let useImperativeHandle2 _ _ _ _ = ()
let useImperativeHandle3 _ _ _ _ = ()
let useImperativeHandle4 _ _ _ _ = ()
let useImperativeHandle5 _ _ _ _ = ()
let useImperativeHandle6 _ _ _ _ = ()
let useImperativeHandle7 _ _ _ _ = ()
let useId _ () = Melact_server.Component.id (Melact_server.Component.current ())
let startTransition run = run ()
let useTransition () = (false, startTransition)



let forwardRef render props = render props None
let memo component = component
let memoCustomCompareProps component _ = component

module Event = struct
  include React_event
end
