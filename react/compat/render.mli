(** What a React component returns, made into melhole children: elements of every type React 18
    knows, text, arrays with their keys, portals, and Melact children passed through as they are.
    Function and class components are Melact instances, so hooks, context and effects are Melact's. *)

val child : Raw.t -> Melhole.View.child

(** A context object as React's [createContext] makes it, with a Melact context behind it. *)
val context : Raw.t -> Raw.t

(** The value of a React context for the component that is rendering. *)
val read : Raw.t -> Raw.t

(** A portal: [children] mounted into [container], with events going on from its place. *)
val portal : Raw.t -> Dom.element -> Melhole.View.child
