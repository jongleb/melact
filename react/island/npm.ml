(** npm's React 18, which an island renders with: [react], [react-dom] and [react-dom/client], imported as
    [melact-island:react] and so on, which melact.island's bundler plugin resolves to npm's. *)

(** A React element made by npm's [createElement]. *)
type element

(** A function component or any other kind [createElement] takes. *)
type kind

(** A root made by [createRoot]. *)
type root

(** What [useRef] gives: a cell that keeps its value across renders. *)
type 'value cell = { mutable current : 'value }

(** A subscription [useSyncExternalStore] makes, and what ends it. *)
type subscribe = (unit -> unit[@u]) -> (unit -> unit[@u])[@u]

external kind : 'any -> kind = "%identity"
external create_element : kind -> 'props Js.t -> element = "createElement" [@@mel.module "melact-island:react"]
external tag : string -> 'props Js.t -> element = "createElement" [@@mel.module "melact-island:react"]
external tag_with : string -> 'props Js.t -> element array -> element = "createElement" [@@mel.module "melact-island:react"] [@@mel.variadic]
external many : element array -> element = "%identity"
external memo : ('props Js.t -> element) -> kind = "memo" [@@mel.module "melact-island:react"]
external use_sync_external_store : subscribe -> (unit -> 'value[@u]) -> 'value = "useSyncExternalStore" [@@mel.module "melact-island:react"]
external use_ref : 'value -> 'value cell = "useRef" [@@mel.module "melact-island:react"]
external use_layout_effect : (unit -> (unit -> unit[@u])[@u]) -> 'deps array -> unit = "useLayoutEffect" [@@mel.module "melact-island:react"]
external create_portal : element -> Dom.element -> element = "createPortal" [@@mel.module "melact-island:react-dom"]
external flush_sync : (unit -> unit[@u]) -> unit = "flushSync" [@@mel.module "melact-island:react-dom"]
external create_root : Dom.element -> root = "createRoot" [@@mel.module "melact-island:react-dom/client"]
external render : root -> element -> unit = "render" [@@mel.send]
