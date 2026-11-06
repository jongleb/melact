(** reason-react's [ReactDOM.Client] for melact: roots that render or hydrate a React element. *)

(** A container element and what is rendered into it. *)
type root

val createRoot : Dom.element -> root
val hydrateRoot : Dom.element -> React.element -> root

(** Melact's own, not React's: leaves a server's page as the server wrote it, rendering no component
    and running no effect, until the first click, key, input, submit or pointer press inside
    [container]; that input hydrates it as [hydrateRoot] does, runs its effects and then reaches its
    handlers. [render] and [unmount] take it over or let it go first. *)
val resumeRoot : Dom.element -> React.element -> root
val render : root -> React.element -> unit
val unmount : root -> unit -> unit
