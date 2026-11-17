(** What melact-ppx reads from types with [-typed] ({!Melhole_typed.Site}, {!Melhole_typed.Question}). *)

(** What a value is to JSX, by its type. *)
type component =
  | Compiled  (** [labels React.props -> React.element]: a [[@react.component]] compiled by melact-ppx. *)
  | Of_props of Melhole_typed.Answer.t  (** [props -> React.element], reason-react's [React.component]: its props type. *)

val component : Melhole_typed.Answer.t -> component option
val element : Melhole_typed.Answer.t -> [ `Element | `Other ]

(** The labels of a compiled component's props, from [< x : unit; y : unit option > React.props -> React.element]. *)
val labels : Melhole_typed.Answer.t -> Ppxlib.arg_label list option
