(** React's components on top of melhole: instances with hook slots, effects in commit order,
    context, and the scheduler that re-renders the instances whose state changed. *)

(** A mounted component, as seen by the hooks it calls. *)
type instance

(** When an effect runs after its instance is patched. *)
type timing =
  | Layout  (** Synchronously, before the browser paints. *)
  | Passive  (** After the whole flush, once the browser has painted. *)

(** Within one commit every cleanup runs before any effect, as in React. *)
type phase = Cleanup | Run

val component : Component.t -> Melhole.View.input array -> (unit -> Melhole.View.child) -> Melhole.View.child
val provide : 'value Context.t -> 'value -> Melhole.View.child -> Melhole.View.child
val current : unit -> instance
val slot : instance -> 'a Hook.key -> (unit -> 'a) -> 'a
val invalidate : instance -> unit
val after_commit : instance -> timing -> phase -> (unit -> unit) -> unit
val on_unmount : instance -> (unit -> unit) -> unit
val consume : instance -> 'value Context.t -> 'value
val settle : unit -> unit
val flush : unit -> unit
