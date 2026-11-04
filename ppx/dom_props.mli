(** reason-react's DOM props, and how melact-ppx writes each one. *)

(** The OCaml type of a prop and how it becomes an attribute value. *)
type value =
  | Text  (** [string], written as is. *)
  | Flag  (** [bool]: the attribute is present or absent. *)
  | Booleanish  (** [bool]: written as ["true"] or ["false"]. *)
  | Integer  (** [int]. *)
  | Decimal  (** [float]. *)

type kind =
  | Attribute of string * value  (** The HTML attribute name. *)
  | Property of string * value  (** The JS property name. *)
  | Handler of string * string  (** The DOM event and the [ReactEvent] family. *)
  | Style
  | Ref
  | Inner_html  (** [dangerouslySetInnerHTML]. *)
  | Ignored  (** Accepted and dropped, like [suppressHydrationWarning]. *)

val find : string -> kind option
