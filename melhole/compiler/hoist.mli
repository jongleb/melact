(** Definitions lifted out of expressions to just before the structure item that needs them. *)

val hoist : loc:Ppxlib.location -> string -> Ppxlib.expression -> Ppxlib.expression

(** A type declaration lifted the same way, given its fresh name; returns the name. *)
val declare : loc:Ppxlib.location -> string -> (string -> Ppxlib.type_declaration) -> string

val structure :
  (Ppxlib.structure_item -> Ppxlib.structure_item) -> Ppxlib.structure -> Ppxlib.structure
