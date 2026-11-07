(** What melact-ppx knows about a component's render from its body alone. *)

(** Whether a render reads only what React lets it read. *)
type rendering =
  | Pure  (** Props, state, context, hook values and constants: nothing a DOM write or another render can change. *)
  | Impure  (** A ref, a reference cell, the clock, a getter called with [()], an unknown hook or construct. *)

(** [rendering body]: how the body of a [@react.component] reads while it renders. A function's body
    counts as run during the render unless the function is a JSX prop or the callback of an effect, a
    reducer or [useCallback]. *)
val rendering : Ppxlib.expression -> rendering
