(** The work a run does, counted by patching jsdom's prototypes and by the programs themselves. *)

(** A kind of work. DOM writes count only on nodes in the document. *)
type kind =
  | Moved  (** A node already in the document inserted again. *)
  | Inserted  (** A node put into the document. *)
  | Removed  (** A node other than text taken out of the document, also by [textContent] of its parent. *)
  | Attribute  (** An attribute set or removed. *)
  | Class  (** [className] set, or a class added, removed or toggled. *)
  | Text  (** [data] or [nodeValue] set, or [textContent] or [innerHTML] set over text or to text. *)
  | Style  (** A style property set or removed. *)
  | Property  (** A form control's value, checked or selected state set. *)
  | Created  (** A node made by [createElement], [createTextNode], [cloneNode], [importNode]. *)
  | Forced_layout  (** A layout read with a DOM write since the layout read before it. *)
  | Frame_layout  (** The layout before the next paint, when a step ends with a write after its last layout read. *)
  | Layout_read  (** [offsetTop], [getBoundingClientRect], [clientWidth], [scrollTop] and the like. *)
  | Rendered  (** A component body run. *)
  | Effect_ran  (** An effect or layout effect run. *)
  | Evaluated  (** A hole expression evaluated. *)
  | Viewed  (** A Meltea view function called. *)
  | Listed  (** A loop's source turned into an array. *)
  | Keyed  (** A row's key computed. *)
  | Projected  (** A row's projection computed. *)
  | Refreshed  (** A row drawn again by its refresh or row function. *)
  | Walked  (** A step of a DOM walk: a TreeWalker or NodeIterator move, compareDocumentPosition, contains. *)
  | Jobs_moved  (** A cell of an effect queue copied to put effects back in the order of the tree. *)

val kinds : kind list
val name : kind -> string

(** Totals per kind of one step: taking them ends the step, and the next one starts after a paint. *)
type t

val take : unit -> t
val count : t -> kind -> int
val bump : kind -> unit
val seen : kind -> 'a -> 'a
val unobserved : (unit -> 'a) -> 'a
