(** DOM elements whose tag is known only at run time, written as React's server writes them. *)

(** A prop as the element gets it, already named as React's server names its attribute. *)
type prop =
  | Attribute of string * string
  | Present of string  (** A boolean attribute that is on. *)
  | Number of string * int  (** [cols], [rows], [size] and [span] are written only from 1. *)
  | Value of string
  | Default_value of string
  | Checked of bool
  | Default_checked of bool
  | Selected of bool
  | Style of (string * string) list
  | Inner_html of string

(** The element with its props in the order given and its children: an input's [checked] and
    [value] last, a textarea's value as its text, a select's value chosen in its options. *)
val element : string -> prop list -> Melhole_server.child -> Melhole_server.child
