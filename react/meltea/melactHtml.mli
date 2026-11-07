(** Melact elements in a Meltea view: the bridge while a leaf widget still has hooks. *)

(** [element make]: the element [make send] makes, where [send] dispatches a message to the
    program; the widget's effects run after the program's draw, as after a Melact render. *)
val element : (('msg -> unit) -> React.element) -> 'msg Html.t
