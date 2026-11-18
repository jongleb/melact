(** Which labels of a component reach [React.cloneElement], as a fact on its [makeProps] that callers read from its [.cmi]. *)

(** What the typed scan of a component found. *)
type t = {
  labels : string list;  (** The labels whose elements reach a clone, directly or through another component's cloned label. *)
  traced : Ppxlib.Location.t list;  (** The [React.cloneElement] calls whose element comes, on every path, from labels or literals. *)
  literals : Ppxlib.Location.t list;  (** The JSX literals whose elements reach one of those calls. *)
  misses : Ppxlib.Location.t list;  (** Elements given to a label their component clones, from somewhere the scan cannot see as JSX. *)
  checked : Ppxlib.Location.t list;  (** Elements given to a label their component clones, traced to labels or literals. *)
}

(** Labels the untyped pass nominates, for sites the typed pass then decides. *)
val candidates : of_component:(Ppxlib.longident -> string list) -> Ppxlib.expression -> string list

(** JSX literals of these bindings whose elements may reach a clone, for sites the typed pass then decides. *)
val literals : of_component:(Ppxlib.longident -> string list) -> Ppxlib.value_binding list -> Ppxlib.Location.t list

val fact : loc:Ppxlib.location -> string list -> Ppxlib.attribute

(** The cloned labels a compiled component's [makeProps] records, looked up before typing. *)
val imported : Ppxlib.longident -> string list

(** The component bindings of the file being rewritten: where each is, and the name of its [makeProps]. *)
val components : (Ppxlib.Location.t * string) list ref

(** The typed scan of every component binding of a file, by binding location, in file order. *)
val in_file : Melhole_typed.File.t -> (Ppxlib.Location.t * t) list

(** The typed scan of a whole file: every traced call and every literal it clones, in components or not. *)
val whole : Melhole_typed.File.t -> t

(** The cloned labels of the [makeProps] a typed identifier names: its fact, or this file's scan. *)
val known : Melhole_typed.File.t -> Ocaml_common.Types.value_description -> string list

(** A typed file's structure with every element in [misses] wrapped in [React.unclonable], whose alert reports it. *)
val flagged : Melhole_typed.File.t -> Ppxlib.structure -> Ppxlib.structure
