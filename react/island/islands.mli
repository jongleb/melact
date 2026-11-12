(** Islands of npm's React inside Melact: one shared root on a detached element, each island a portal
    into an element Melact owns, rendering from a store of its own that Melact writes when a prop
    changes; one [flushSync] per Melact commit tells React of every store that changed. Melact content
    passed in props lives in a slot that Melact patches itself, so changing it does not wake React. *)

(** A JavaScript React component, as its module exports it. *)
type foreign

(** The props object an island is given, as [makeProps] builds it. *)
type props

(** The component with its props, as Melact content. *)
val mount : foreign -> props -> Melhole.View.child
