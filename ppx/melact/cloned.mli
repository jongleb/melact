(** Which labels of a component reach [React.cloneElement], as a fact on its [makeProps] that callers read from its [.cmi]. *)

(** What the typed scan of a component found. *)
type t = {
  labels : string list;  (** The labels whose elements reach a clone, directly or through another component's cloned label. *)
  traced : Ppxlib.Location.t list;  (** The [React.cloneElement] calls whose element comes from one of those labels. *)
}

(** Labels the untyped pass nominates, for sites the typed pass then decides. *)
val candidates : of_component:(Ppxlib.longident -> string list) -> Ppxlib.expression -> string list

val fact : loc:Ppxlib.location -> string list -> Ppxlib.attribute

(** The cloned labels a compiled component's [makeProps] records, looked up before typing. *)
val imported : Ppxlib.longident -> string list

(** The component bindings of the file being rewritten: where each is, and the name of its [makeProps]. *)
val components : (Ppxlib.Location.t * string) list ref

(** The typed scan of every component binding of a file, by binding location, in file order. *)
val in_file : Melhole_typed.File.t -> (Ppxlib.Location.t * t) list

(** The cloned labels of the [makeProps] a typed identifier names: its fact, or this file's scan. *)
val known : Melhole_typed.File.t -> Ocaml_common.Types.value_description -> string list
