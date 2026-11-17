(** Builder calls ([M.makeProps …]) in a file that loads [M] by [Js.import], made props objects once typed, so [M] stays in its chunk. *)

val structure : Ppxlib.structure -> Ppxlib.structure

(** Marks a builder call that the typed pass turns into [React.lazy_props (Melact_lazy.props …)]. *)
val lazy_props : string
