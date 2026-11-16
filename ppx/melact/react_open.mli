(** A local [open React] pushed down to the expressions that read React's names, so that a hook under it
    is named in full and the update graph sees it. Where a binding between the open and a read names
    something of React's, the open stays where it is. *)

val qualified : Ppxlib.expression -> Ppxlib.expression
