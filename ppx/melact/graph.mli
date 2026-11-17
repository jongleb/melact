(** What melact-ppx knows about a component's render from its body alone. *)

(** Why melact-ppx gives up on what a body does: where, and what is there. *)
type why = { loc : Ppxlib.Location.t; reason : string }

(** Whether a render reads only what React lets it read. *)
type rendering =
  | Pure  (** Props, state, context, hook values and constants: nothing a DOM write or another render can change. *)
  | Reads_the_page of why
      (** Also the [current] of a ref the body made with [useRef]: an element it reads the layout of, or a value
          an effect or a handler left there. Nothing is written. The first such read. *)
  | Impure of why
      (** Another ref, a write to a ref, a reference cell, the clock, a getter called with [()], an unknown hook or
          construct: the first one met. *)

(** An argument of a call: by its place among the unlabelled ones, or by its label. *)
type argument = Position of int | Label of string

(** Whether a custom hook reads the page while it renders: the [current] of a ref it made. A component that calls
    one reads the page, and what the hook returns is made again on every render. *)
type page = Unread | Read

(** What a custom hook takes on every call: [slots] of its own, and those of the hook given for each label of
    [through], once per call of it; [later] are the arguments it calls only after the render (in an effect, a
    reducer, a callback or a handler), or hands only to such a place. *)
type fact = { slots : int; through : string list; later : argument list; page : page }

(** What melact-ppx knows of a callee that is a hook: its fact, or that it is a hook it could not count. *)
type 'known summary = Counted of 'known | Uncounted

(** [rendering body]: how the body of a [@react.component] reads while it renders. A function's body
    counts as run during the render unless the function is a JSX prop, the callback of an effect, a
    reducer or [useCallback], or an argument a custom hook only calls later. [hooks] gives, for a custom
    hook known to be pure, the arguments its fact says it calls only after the render. *)
val rendering : hooks:(Ppxlib.expression -> fact summary option) -> Ppxlib.expression -> rendering

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
  | Bound of Ppxlib.value_binding  (** A binding with a polymorphic annotation, made on every render as written. *)

(** A body as steps, then the expression it returns and the mask of what that reads. *)
type plan = { steps : step list; result : Ppxlib.expression; reads : int }

(** Every source bit: the mask of a step that runs on every render. *)
val every_source : int


(** A custom hook's fact, holding when none of [values], hook-named identifiers read as values, is a function and
    every condition holds. *)
type 'condition counted = { fact : fact; values : Ppxlib.expression list; conditions : 'condition list }

(** What the update graph makes of a value that may read mutable state. *)
type volatile =
  | Renders_whole  (** Nothing: the component renders whole. A pure body. *)
  | Runs_every_render  (** A step that reads it runs on every render, as does what is made from it. A body that reads the page. *)

(** [plan ~inputs ~props ~volatile body]: the update graph of a body that writes nothing, given the
    number of inputs the component compares and the input bits of each prop variable; [Error] with why when a
    hook, a construct or the number of sources is beyond it, and the component renders whole. The
    first hook slot is the component's memory. *)
val plan :
  hooks:(Ppxlib.expression -> fact option) ->
  inputs:int ->
  props:(string * int) list ->
  volatile:volatile ->
  Ppxlib.expression ->
  (plan, why) result

(** [slots ~hooks definition]: what a custom hook takes on every call, when its body is pure, calls its hooks at
    its top level and calls only React's hooks, custom hooks known by [hooks] and hooks given for its labelled
    parameters. *)
val slots :
  hooks:(Ppxlib.expression -> 'condition counted summary option) -> Ppxlib.expression -> ('condition counted, why) result
