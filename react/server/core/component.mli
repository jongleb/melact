(** React's components on a server: rendered once, when written, with their hooks' initial values. *)

(** One component rendering: its hook slots, the ids it took, and whether it renders again. *)
type frame

(** A component that calls hooks. Written, it renders [body] with fresh slots, again while a state
    set during that render changes it (as React's server does, at most 25 times), and writes what it
    returned; the children of a component that took an id are one position further down, as React
    numbers them. *)
val render : (unit -> Melhole_server.child) -> Melhole_server.child

(** The component rendering now; a hook called anywhere else fails. *)
val current : unit -> frame

val take : frame -> 'a Hook.key -> (unit -> 'a) -> 'a

(** The component's next [useId], as React's server spells it: [:R], the tree id, then for the
    second and later ones [H] and their number, in base 32, and [:]. *)
val id : frame -> string

(** A [useState] or [useReducer] slot. *)
type ('state, 'action) state

(** [state key reduce initial]: the state with the actions dispatched during this render applied,
    and the dispatch. An action dispatched once the render is over is dropped, as on React's server. *)
val state :
  ('state, 'action) state Hook.key -> ('state -> 'action -> 'state) -> (unit -> 'state) -> 'state * ('action -> unit)

(** A [useMemo] or [useCallback] slot: its dependencies and value. *)
type ('deps, 'value) memo

val memo : ('deps, 'value) memo Hook.key -> ('deps -> 'deps -> Deps.change) -> 'deps -> (unit -> 'value) -> 'value
