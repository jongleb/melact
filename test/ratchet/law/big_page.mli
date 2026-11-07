(** The page of test/ratchet/bigpage: rows of twelve elements each, a debounced search field, rows that
    read their offsetTop, forty rows marked from a context and a popover, run through
    test/ratchet/bigpage/scenario.mjs by the driver of test/ratchet/classics. *)

(** A build of the page. *)
type build = React | Melact

val run : build -> int -> Classics.run Js.Promise.t
val keystroke : build -> int -> Counters.t Js.Promise.t
