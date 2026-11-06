(** React's components on top of melhole: instances with hook slots, effects in commit order,
    context, and the scheduler that re-renders the instances whose state changed. *)

(** A mounted component, as seen by the hooks it calls. *)
type instance

(** When an effect runs after its instance is patched. *)
type timing =
  | Layout  (** Synchronously, before the browser paints. *)
  | Passive  (** After the whole flush: at once after a discrete event, as React 18, else once the browser has painted. *)

(** Within one commit every cleanup runs before any effect, as in React. *)
type phase = Cleanup | Run

(** Whatever a component threw: an OCaml exception or the value a JavaScript [throw] gave. *)
type caught

(** An error boundary: [children] until a descendant throws while rendering or in an effect, then
    [recover] of what it threw, as React's [componentDidCatch] does. *)
val catch : recover:(caught -> Melhole.View.child) -> Melhole.View.child -> Melhole.View.child

(** A promise a component waits on. *)
type thenable

(** What [use] throws for a promise that has not settled: the nearest Suspense boundary catches it. *)
exception Suspended of thenable

(** A Suspense boundary: [children] until a descendant suspends, then [fallback] until the promise
    settles, with children already shown kept, hidden, as React keeps them. *)
val suspend : fallback:Melhole.View.child -> Melhole.View.child -> Melhole.View.child

val component : Component.t -> Melhole.View.input array -> (unit -> Melhole.View.child) -> Melhole.View.child
val provide : 'value Context.t -> 'value -> Melhole.View.child -> Melhole.View.child
val current : unit -> instance
val slot : instance -> 'a Hook.key -> (unit -> 'a) -> 'a
val invalidate : instance -> unit

(** Marks an instance to render again because a state value changed; [check] tells, when the render
    is due, whether the value still differs from the one it last rendered with. If no check does
    and nothing else asked, the render is skipped, as React bails out. *)
val invalidate_state : instance -> (unit -> Melhole.View.change) -> unit
val after_commit : instance -> timing -> phase -> (unit -> unit) -> unit
val on_unmount : instance -> (unit -> unit) -> unit
val consume : instance -> 'value Context.t -> 'value
val settle : unit -> unit
val flush : unit -> unit
