(** What melact-ppx reads from types with [-typed] ({!Melhole_typed.Site}, {!Melhole_typed.Question}). *)

(** What a value is to JSX, by its type. *)
type component =
  | Compiled  (** [x_props -> React.element]: a [[@react.component]] compiled by melact-ppx. *)
  | Of_props of Melhole_typed.Answer.t  (** [props -> React.element], reason-react's [React.component]: its props type. *)

val component : Melhole_typed.Answer.t -> component option
val element : Melhole_typed.Answer.t -> [ `Element | `Other ]
