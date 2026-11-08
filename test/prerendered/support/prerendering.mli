(** Laws for a keyed-rows benchmark page built at build time: its shipped HTML, resumed by its
    shipped client, against the same app's client mounting on an empty root. *)

(** Registers the laws. [page] is the shipped index.html, [renders] counts the app's view or root
    component runs, and [import] loads a client module of the test's own folder by its file name
    ([mounted.mjs] or [resumed.mjs]) with a query that makes every load a fresh start. *)
val laws : framework:string -> page:string -> renders:int ref -> import:(string -> unit Js.Promise.t) -> unit
