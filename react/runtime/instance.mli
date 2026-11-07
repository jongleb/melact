(** React's components on top of melhole: instances with hook slots, effects in commit order,
    context, and the scheduler that re-renders the instances whose state changed. *)

(** A mounted component, as seen by the hooks it calls. *)
type instance

(** What changed since an instance last rendered. *)
type sources =
  | Every  (** Not known: a mount, a boundary, a parent without inputs to compare; every step runs again. *)
  | Bits of int  (** The bits of the inputs, hook slots and context reads that changed, as melact-ppx numbers them. *)

(** Whether a step of an update graph reads a source that changed. *)
type reach = Reached | Unreached

(** [reaches sources mask]: whether a step whose sources are the bits of [mask] runs again. *)
val reaches : sources -> int -> reach

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

(** Counts the positions of the next hydration from the root, as React's [useId] does. *)
val number_from_root : unit -> unit

(** The instance's next [useId]: while it takes over a server's nodes, React's id for its position,
    as the server wrote it; else one of Melact's own. *)
val id : instance -> string

val component : Component.t -> Melhole.View.input array -> (unit -> Melhole.View.child) -> Melhole.View.child
val provide : 'value Context.t -> 'value -> Melhole.View.child -> Melhole.View.child
val current : unit -> instance

(** How a pass that sorts effects orders two instances: negative when the first comes first in the
    tree, [0] to leave it to document order. melact.compat sets it to order through its portals. *)
val tree_order : (instance -> instance -> int) option ref

val parent : instance -> instance option

(** The deepest last node of what the instance shows, if it shows anything. *)
val last_node : instance -> Dom.node option

(** The component that is rendering, or whose holes are being written, if any. *)
val writing_component : unit -> string option
val slot : instance -> 'a Hook.key -> (unit -> 'a) -> 'a
val invalidate : instance -> unit

(** Marks an instance to render again because a state cell changed; [check] tells, when the render
    is due, whether the cell's value still differs from the one it last rendered with, and [bit] is
    the cell's source. If no check does and nothing else asked, the render is skipped, as React bails out. *)
val invalidate_state : instance -> 'cell -> ('cell -> Melhole.View.change) -> sources -> unit

(** The source of a state cell made by the instance's next hook: its bit after the inputs and the hooks
    before it, as melact-ppx numbers them; past the thirtieth, [Every]. *)
val cell_source : instance -> sources

(** What changed since the last render of the component under way: a component compiled with its
    update graph skips what reads none of it. *)
val changed : unit -> sources

(** Passes over the next hook of the component rendering, whose value its render does not need. *)
val skip_hook : unit -> unit

(** What a render returns when nothing its output reads changed: its holes stay as they are. *)
val unchanged : Melhole.View.child

(** [consume_source instance source context]: the value of the nearest provider, which renders the
    instance again with [source] among its changed sources when the value changes. *)
val consume_source : instance -> sources -> 'value Context.t -> 'value
val after_commit : instance -> timing -> phase -> (unit -> unit) -> unit

(** An effect hook: made once, its cleanup and run queued after each commit that changes its
    dependencies, and its cleanup run when its instance unmounts. *)
type 'deps effect_hook

val start_effect : instance -> timing -> 'deps -> (unit -> (unit -> unit) option) -> 'deps effect_hook
val deps : 'deps effect_hook -> 'deps
val rerun : 'deps effect_hook -> 'deps -> (unit -> (unit -> unit) option) -> unit

(** Whether an effect was queued by the render under way, which a render that set its own state
    runs again: then it takes that attempt's effect whatever its dependencies. *)
val queued : 'deps effect_hook -> [ `This_render | `Earlier ]

(** The value of the instance's next hook when an earlier render made it, else [None]: then [put] makes it. *)
val found : instance -> 'a Hook.key -> 'a option

val put : instance -> 'a Hook.key -> 'a -> unit
val on_unmount : instance -> (unit -> unit) -> unit
val consume : instance -> 'value Context.t -> 'value
val settle : unit -> unit
val flush : unit -> unit

(** Settles what a root's render made; inside a discrete event its passive effects run at the next
    microtask, as React 18 runs those of a commit in its sync lane, before any later event. *)
val settle_in_event : unit -> unit

(** Runs [job] in a later task, outside any render: a deferred value catching up. *)
val defer : (unit -> unit) -> unit

(** Runs the deferred jobs now, as [act] does. *)
val run_deferred : unit -> [ `Ran | `Idle ]
