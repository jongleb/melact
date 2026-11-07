(** React's event props on DOM elements, delivered as synthetic events. Bubbling handlers go
    through melhole's delegated walk, so they run in one walk with compiled Melact handlers; capture
    handlers, enter and leave, and events that only reach their target have listeners of their own.
    A portal's top nodes continue the walk at the portal's place, as React bubbles through portals. *)

(** What an element prop means for events. *)
type t

(** [None] when the prop is not an event handler. [tag] decides what [onChange] listens to. *)
val of_prop : tag:string -> string -> t option

(** Sets the handler of an event prop on an element, or removes it with [None]. *)
val put : Dom.element -> t -> Raw.t option -> unit

(** Marks a top node of a portal: events from inside it go on to [parent] and its ancestors. *)
val bridge : Dom.node -> parent:Dom.node -> unit
