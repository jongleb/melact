(** npm react-dom's API, as [react-dom.js] and [react-dom-client.js] export it. *)

val createPortal : Raw.t -> Raw.t -> Raw.t -> Raw.t

(** Runs the function, then renders what it asked for at once, outside a render. *)
val flushSync : Raw.t -> Raw.t

val createRoot : Dom.element -> Raw.t -> Raw.t
val render : Raw.t -> Dom.element -> Raw.t -> unit
val unmountComponentAtNode : Dom.element -> bool
val findDOMNode : Raw.t -> Raw.t
