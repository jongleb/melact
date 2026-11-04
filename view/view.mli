(** Descriptions of DOM content, and the patcher that turns the mounted
    description into the next one by writing only the holes that changed.
    Values are compared physically: mutating data in place is invisible. *)

type child

(** The value of one template hole. *)
type hole =
  | HText of string
  | HAttr of string option  (** [None] removes the attribute. *)
  | HProp : 'a -> hole  (** Written as a JS property ([value], [checked]). *)
  | HClass of string list  (** The classes that are on. *)
  | HStyle of (string * string) list  (** camelCase property, value. *)
  | HHandler of (Dom.event -> unit)  (** Replaced on every patch, never compared. *)
  | HRef of (Dom.element -> unit)  (** Called when mounted or replaced. *)
  | HChild of child

val text : string -> child
val empty : child
val list : child list -> child
val keyed : (string * child) list -> child
val tpl_instance : Template.t -> hole array -> child
val lazy1 : ('a -> child) -> 'a -> child
val lazy2 : ('a -> 'b -> child) -> 'a -> 'b -> child

type mounted

val mount :
  child -> parent:'a Dom.node_like -> before:'b Dom.node_like option -> mounted

val patch : mounted -> child -> unit
val unmount : mounted -> unit
