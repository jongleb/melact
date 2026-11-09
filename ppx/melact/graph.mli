(** What melact-ppx knows about a component's render from its body alone. *)

(** Whether a render reads only what React lets it read. *)
type rendering =
  | Pure  (** Props, state, context, hook values and constants: nothing a DOM write or another render can change. *)
  | Reads_the_page
      (** Also the [current] of a ref the body made with [useRef]: an element it reads the layout of, or a value
          an effect or a handler left there. Nothing is written. *)
  | Impure
      (** Another ref, a write to a ref, a reference cell, the clock, a getter called with [()], an unknown hook or
          construct. *)

(** [rendering body]: how the body of a [@react.component] reads while it renders. A function's body
    counts as run during the render unless the function is a JSX prop or the callback of an effect, a
    reducer or [useCallback]. [hooks] gives the hook slots of a custom hook known to be pure, from its fact. *)
val rendering : hooks:(Ppxlib.expression -> int option) -> Ppxlib.expression -> rendering

(** One step of a body read as an update graph. A mask is the set of sources (bits of props, state
    cells and contexts) whose change makes the step run again; a render that knows nothing of what
    changed runs every step. *)
type step =
  | Statement of Ppxlib.expression  (** Run on every render. *)
  | Called of Ppxlib.pattern * Ppxlib.expression  (** A hook called on every render: a state cell, a ref, an id. *)
  | Context of { pattern : Ppxlib.pattern; context : Ppxlib.expression; bit : int }
  | Memo of { pattern : Ppxlib.pattern; hook : Ppxlib.expression; mask : int }  (** [useMemo], [useCallback]. *)
  | Effect of { hook : Ppxlib.expression; mask : int }  (** An effect, skipped while its dependencies' sources stay. *)
  | Derived of { pattern : Ppxlib.pattern; value : Ppxlib.expression; mask : int }

(** A body as steps, then the expression it returns and the mask of what that reads. *)
type plan = { steps : step list; result : Ppxlib.expression; reads : int }

(** Every source bit: the mask of a step that runs on every render. *)
val every_source : int

(** What the update graph makes of a value that may read mutable state. *)
type volatile =
  | Renders_whole  (** Nothing: the component renders whole. A pure body. *)
  | Runs_every_render  (** A step that reads it runs on every render, as does what is made from it. A body that reads the page. *)

(** [plan ~inputs ~props ~volatile body]: the update graph of a body that writes nothing, given the
    number of inputs the component compares and the input bits of each prop variable; [None] when a
    hook, a construct or the number of sources is beyond it, and the component renders whole. The
    first hook slot is the component's memory. *)
val plan :
  hooks:(Ppxlib.expression -> int option) ->
  inputs:int ->
  props:(string * int) list ->
  volatile:volatile ->
  Ppxlib.expression ->
  plan option

(** [slots ~hooks definition]: the hook slots a custom hook takes on every call, when its body is pure,
    calls its hooks at its top level and calls only React's hooks and custom hooks known by [hooks]. *)
val slots : hooks:(Ppxlib.expression -> int option) -> Ppxlib.expression -> int option
