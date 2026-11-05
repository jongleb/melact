(** reason-react's [ReactDOM.Client] for melact: roots that render or hydrate a React element. *)

(** A container element and what is rendered into it. *)
type root

val createRoot : Dom.element -> root
val hydrateRoot : Dom.element -> React.element -> root
val render : root -> React.element -> unit
val unmount : root -> unit -> unit
