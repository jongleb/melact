(** A DOM element of a React element with a string type, its props written by react-dom's rules:
    attribute names, booleans, styles with [px], controlled values, event props and refs. *)

(** [child tag props reference children]: the element and its children, patched in place while the
    tag stays the same. *)
val child : string -> Raw.t -> Raw.t -> Melhole.View.child -> Melhole.View.child

(** Gives a ref its value: a function ref is called with it, an object ref gets it as [current]. *)
val assign : Raw.t -> Raw.t -> unit
