type t =
  | Possibly_polymorphic
  | Monomorphic

val of_let : Ppxlib.pattern -> Ppxlib.expression -> Ppxlib.expression -> t
