(** The apps of bench/classics, each run in jsdom through its own scenario under React 18 and under
    Melact by the driver in test/ratchet/classics, with virtual time. *)

(** One step of a scenario, as its module exports it: a name and what it does. *)
type step = < name : string > Js.t

(** What the driver returns for one run. *)
type run = < outcome : Ratchet.outcome ; names : string array ; failures : string array ; elements : int > Js.t

(** When a part of the corpus runs. *)
type pace =
  | Quick  (** In every run of the suite. *)
  | Slow  (** Only with RATCHET_SLOW set, as CI and lower.mjs set it: these apps take long in jsdom. *)

(** An app of bench/classics, by its path there, with the steps of its scenario that cannot run in
    jsdom, each with the reason. *)
type app = { path : string; skipped : (string * string) list }

val scenario : string -> step array Js.Promise.t
val driven : build:string -> start:('build -> unit) -> step array -> run Js.Promise.t
val laws : part:string -> pace:pace -> app list -> unit
