open Melhole

(** What changed since an instance last rendered. *)
type sources =
  | Every  (** Not known: a mount, a boundary, a parent without inputs to compare; every step runs again. *)
  | Bits of int  (** The bits of the inputs, hook slots and context reads that changed, as melact-ppx numbers them. *)

(** Whether a step of an update graph reads a source that changed. *)
type reach = Reached | Unreached

let union first second =
  match (first, second) with
  | Every, _ | _, Every -> Every
  | Bits first, Bits second -> Bits (first lor second)

let reaches sources mask =
  match sources with
  | Every -> Reached
  | Bits bits -> ( match bits land mask with 0 -> Unreached | _ -> Reached)

(** When an effect runs after its instance is patched. *)
type timing =
  | Layout  (** Synchronously, before the browser paints. *)
  | Passive  (** After the whole flush: at once after a discrete event, as React 18, else once the browser has painted. *)

(** Within one commit every cleanup runs before any effect, as in React. *)
type phase = Cleanup | Run

(** Whatever a component threw. *)
type caught

external caught_of : 'a -> caught = "%identity"

(** A mounted component: its hook slots, its output and its effects. *)
(** A JavaScript [Set] of the instances that read a provider. *)
type audience

(** A JavaScript [Map] from an instance that read a provider to the bits of its sources the provider's value is. *)
type readers

(** Where an instance is as React's [useId] numbers positions: known when it took over a server's
    nodes, else not counted. *)
type numbered = Unnumbered | Numbered of Melhole_server.Tree.t

type instance = {
  parent : instance option;  (** The nearest enclosing instance. *)
  depth : int;
  tree : numbered;
  mutable ids : int;  (** The [useId]s its first render took. *)
  slots : Hook.slots;
  kind : kind;
  mutable status : status;
  mutable output : View.live;
  mutable region : region;
  mutable pending : job list;  (** Effects of the last render, newest first. *)
  mutable teardown : ending list;  (** Run on unmount, newest first. *)
  mutable renders : int;  (** How many times it started rendering. *)
  mutable providers : instance list;  (** The providers above it that it has read, found once: they stay while it does. *)
  mutable prepared : prepared;
}

(** A render made ahead of its round, while the page was still as the update found it. *)
and prepared = Unprepared | Prepared of (View.child, exn) result

and kind =
  | Renders of {
      component : Component.t;
      mutable inputs : View.input array;
      mutable render : unit -> View.child;
    }
  | Provides : {
      context : 'value Context.t;
      mutable value : 'value;
      mutable children : View.child;
      consumers : readers;  (** The instances that read the value since it last changed, with the sources it is to them. *)
      known : audience;  (** The mounted instances that ever read it, each leaving once it unmounts. *)
    }
      -> kind
  | Catches of catching
  | Suspends of suspending

(** What a Suspense boundary shows and keeps: its children, or its fallback while they wait. *)
and suspending = {
  mutable wanted : View.child;  (** The children it is to show. *)
  mutable fallback : View.child;
  mutable waiting : waiting;
  mutable content : View.live;  (** The children, shown or hidden. *)
  mutable backup : View.live;  (** The fallback while it is shown. *)
  opening : Dom.text;
  closing : Dom.text;
}

(** Where a Suspense boundary is, pass by pass. *)
and waiting =
  | Showing
  | Suspending of { promise : thenable; throwers : instance list }  (** A child suspended during this pass. *)
  | Waiting of { content : content; throwers : instance list }  (** The fallback shows until the promise settles. *)
  | Retrying of { content : content; throwers : instance list }  (** The promise settled: the children render again. *)

(** The children of a Suspense boundary while its fallback shows. *)
and content =
  | Absent  (** Never shown: they are built again. *)
  | Hidden of (Dom.node * hidden) list  (** Shown before: kept in the DOM, hidden, with their state. *)

(** How a node of hidden content looked. *)
and hidden = Displayed of string | Texted of string

(** A promise a component waits on. *)
and thenable

(** What an error boundary shows and keeps: its children until a descendant throws, then the fallback. *)
and catching = {
  mutable children : View.child;
  recover : caught -> View.child;
  mutable failure : failure;
  start : Dom.text;
  finish : Dom.text;
}

(** Where an error boundary is in React's recovery, pass by pass. *)
and failure =
  | Healthy
  | Caught of { error : caught; thrower : instance }  (** Caught while rendering: the children go at commit. *)
  | Struck of caught  (** Caught in an effect: the children go on the next pass. *)
  | Failed of caught  (** Shows the fallback. *)

(** What a commit runs after it: an effect hook's cleanup and run, or one piece of work. *)
and job =
  | Effect : 'deps effect_hook -> job  (** Its cleanup in the cleanup phase, its run in the run phase. *)
  | Work of { owner : instance; timing : timing; phase : phase; work : unit -> unit }

(** An effect hook, made once and queued after every commit that changes its dependencies. *)
and 'deps effect_hook = {
  host : instance;
  when_run : timing;
  mutable deps : 'deps;
  mutable cleanup : (unit -> unit) option;
  mutable run : unit -> (unit -> unit) option;  (** The effect of the render that last changed [deps]. *)
  mutable queued_in : int;  (** The render of its host that last queued it. *)
}

(** What an instance lets go of when it unmounts. *)
and ending =
  | Finishes : 'deps effect_hook -> ending
  | Leaves of { consumers : readers; known : audience }  (** Stops reading a provider. *)
  | Calls of (unit -> unit)

and status = Clean | Dirty of dirt | Unmounted

(** Why an instance is to render again. *)
and dirt =
  | Forced  (** Its parent, a context or a boundary asks for it, without saying what changed. *)
  | Sourced of { mask : sources; checks : checking list }
      (** The props and contexts whose bits are in [mask] changed, and the state cells checked may have: each
          check tells whether a value differs from the one it last rendered with. *)

(** A state cell, how to tell whether its value differs from the one it last rendered with, and its bit. *)
and checking = Checking : 'cell * ('cell -> View.change) * sources -> checking

(** Where an instance sits in the DOM when its output has no nodes. *)
and region =
  | Nodes  (** The output's own nodes locate it. *)
  | Marker of Dom.text  (** An empty text node holds its place. *)

(** What [use] throws for a promise that has not settled: the nearest Suspense boundary catches it. *)
exception Suspended of thenable

(** When an error is thrown, which decides what a boundary keeps of several, as in React. *)
type stage =
  | While_rendering  (** The one thrown later in the tree wins. *)
  | In_effect  (** The one thrown last wins. *)

(** Whether an error boundary still has a step to take in this flush. *)
type outstanding = Quiet | Busy

(** Whether a component given new props renders at once or in the next round, after its siblings. *)
type patching = At_once | Next_round

(** Whether a pass put off any component, so its effects need sorting into the order of the tree. *)
type putting_off = None_put_off | Some_put_off

(** What error boundaries add to a flush: nothing until the first boundary mounts. *)
type recovery = {
  rescue : (stage -> instance -> exn -> unit[@u]);  (** Hands an error to the nearest boundary that can take it. *)
  before_rendering : (unit -> unit[@u]);  (** Boundaries hit by effects drop their children, fallen ones show fallbacks. *)
  after_rendering : (unit -> unit[@u]);  (** Boundaries that caught while rendering drop their children and fail. *)
  outstanding : (unit -> outstanding[@u]);
}

(** Whether a flush is already queued. *)
type schedule = Idle | Queued

(** When the queued render of dirty instances runs, after React's lanes. *)
type render_queue =
  | Unqueued
  | Next_task  (** For an update outside a discrete event: a task of its own, as React's default lane. *)
  | Next_microtask  (** For an update from a discrete event: before the browser paints, as React's sync lane. *)

external audience : unit -> audience = "Set" [@@mel.new]
external join : audience -> instance -> unit = "add" [@@mel.send]
external member : audience -> instance -> bool = "has" [@@mel.send]
external leave : audience -> instance -> unit = "delete" [@@mel.send]
external disband : audience -> unit = "clear" [@@mel.send]
external readers : unit -> readers = "Map" [@@mel.new]
external read_bits : readers -> instance -> sources Js.undefined = "get" [@@mel.send]
external set_bits : readers -> instance -> sources -> unit = "set" [@@mel.send]
external stop_reading : readers -> instance -> bool = "delete" [@@mel.send]
external each_reader : readers -> ((sources -> instance -> unit)[@mel.uncurry]) -> unit = "forEach" [@@mel.send]
external clear_readers : readers -> unit = "clear" [@@mel.send]

let read readers instance bits =
  match (Js.Undefined.toOption (read_bits readers instance), bits) with
  | Some Every, _ -> ()
  | Some (Bits known), Bits more when known lor more = known -> ()
  | Some known, _ -> set_bits readers instance (union known bits)
  | None, _ -> set_bits readers instance bits

(** A JavaScript [Map] from a DOM node to the dirty instances that start at it. *)
type starts

external nodes_of : unit -> starts = "Map" [@@mel.new]
external found_get : starts -> Dom.node -> instance list Js.undefined = "get" [@@mel.send]
external found_set : starts -> Dom.node -> instance list -> unit = "set" [@@mel.send]
external found_delete : starts -> Dom.node -> unit = "delete" [@@mel.send]
external node_contains : Dom.node -> Dom.node -> bool = "contains" [@@mel.send]

(** A JavaScript [Map] from a DOM node to its place in document order. *)
type ranks

external nodes_ranked : unit -> ranks = "Map" [@@mel.new]
external rank_get : ranks -> Dom.node -> int Js.undefined = "get" [@@mel.send]
external rank_set : ranks -> Dom.node -> int -> unit = "set" [@@mel.send]

(** A DOM [TreeWalker]: it visits a subtree's nodes in document order. *)
type walker

external tree_walker : Dom.document -> Dom.node -> int -> walker = "createTreeWalker" [@@mel.send]
external next_node : walker -> Dom.node Js.null = "nextNode" [@@mel.send]

let thrown error =
  match error with
  | Js.Exn.Error raw -> ([%mel.raw "function (error) { throw error }"] : Js.Exn.t -> unit) raw
  | other -> raise other

let rendering = ref None

(** Whether the component rendering now set its own state while rendering, so it renders again. *)
type rerendering = Once | Again

let rerendering = ref Once
let recovery =
  ref
    {
      rescue = (fun [@u] _ _ error -> thrown error);
      before_rendering = (fun [@u] () -> ());
      after_rendering = (fun [@u] () -> ());
      outstanding = (fun [@u] () -> Quiet);
    }
let suspension =
  ref
    {
      rescue = (fun [@u] stage instance error -> !recovery.rescue stage instance error [@u]);
      before_rendering = (fun [@u] () -> ());
      after_rendering = (fun [@u] () -> ());
      outstanding = (fun [@u] () -> Quiet);
    }

let owner = ref None
let dirty = ref []
let layout_cleanups = ref []
let layout_runs = ref []
let passive_cleanups = ref []
let passive_runs = ref []
let render_schedule = ref Unqueued
let passive_schedule = ref Idle

let within cell value run =
  let saved = !cell in
  cell := value;
  match run () with
  | result ->
      cell := saved;
      result
  | exception error ->
      cell := saved;
      raise error

let finish hook =
  Option.iter (fun cleanup -> cleanup ()) hook.cleanup;
  hook.cleanup <- None

let visit_nodes instance visit =
  View.visit instance.output visit;
  match instance.region with Marker node -> visit (Dom_api.to_node node) [@u] | Nodes -> ()

let front_node instance after =
  View.front instance.output
    (match instance.region with Marker node -> Js.Null.return (Dom_api.to_node node) | Nodes -> after)

let patching = ref At_once

let put_off = ref None_put_off
let committed = audience ()
let enqueued = ref 0

let mounting = ref 0

let tree_order = ref None
let parent instance = instance.parent

let last_node instance =
  let last = ref None in
  visit_nodes instance (fun [@u] node -> last := Some node);
  let rec deepest node = Option.fold ~none:node ~some:deepest (Js.Null.toOption (Dom_api.last_child node)) in
  Option.map deepest !last

(** Whether the effects of an instance's write go to the queues when it ends, or wait: in a pass of
    pure instances, until the instances below it that the pass renders later have queued theirs, so
    that the queues come out children first without sorting them. *)
type deferral = Queue_now | Deferring of instance

let deferral = ref Queue_now

let instances =
  View.hosting
    ~visit:(fun [@u] instance visit ->
      match instance.kind with
      | Renders _ | Provides _ -> visit_nodes instance visit
      | Catches catching ->
          visit (Dom_api.to_node catching.start) [@u];
          View.visit instance.output visit;
          visit (Dom_api.to_node catching.finish) [@u]
      | Suspends suspending ->
          visit (Dom_api.to_node suspending.opening) [@u];
          View.visit suspending.content visit;
          View.visit suspending.backup visit;
          visit (Dom_api.to_node suspending.closing) [@u])
    ~first:(fun [@u] instance after ->
      match instance.kind with
      | Renders _ | Provides _ -> front_node instance after
      | Catches catching -> Js.Null.return (Dom_api.to_node catching.start)
      | Suspends suspending -> Js.Null.return (Dom_api.to_node suspending.opening))
    ~let_go:(fun [@u] instance ->
      match instance.kind with
      | Renders _ | Provides _ ->
          View.release instance.output;
          instance.status <- Unmounted;
          List.iter
            (fun ending ->
              match ending with
              | Finishes hook -> finish hook
              | Leaves { consumers; known } ->
                  ignore (stop_reading consumers instance);
                  leave known instance
              | Calls cleanup -> cleanup ())
            (List.rev instance.teardown)
      | Catches _ ->
          View.release instance.output;
          instance.status <- Unmounted
      | Suspends suspending ->
          View.release suspending.content;
          View.release suspending.backup;
          instance.status <- Unmounted)

(** Whether an instance that may read the page renders later in this flush: a pure child given new
    props then waits for the next round, so that its writes do not land between two reads. *)
type reads = Reads_ahead | No_reads_ahead

let reads = ref No_reads_ahead

let reading instance =
  match instance.kind with
  | Renders { component = { rendering = Component.Impure; _ }; _ } -> reads := Reads_ahead
  | Renders _ | Provides _ | Catches _ | Suspends _ -> ()

let mark_dirty instance =
  reading instance;
  instance.prepared <- Unprepared;
  match instance.status with
  | Clean ->
      instance.status <- Dirty Forced;
      dirty := instance :: !dirty
  | Dirty (Sourced _) -> instance.status <- Dirty Forced
  | Dirty Forced | Unmounted -> ()

let sourced instance bits =
  match (bits, instance.status) with
  | Every, (Clean | Dirty (Sourced _)) -> instance.status <- Dirty Forced
  | Bits _, Clean -> instance.status <- Dirty (Sourced { mask = bits; checks = [] })
  | Bits _, Dirty (Sourced { mask; checks }) -> instance.status <- Dirty (Sourced { mask = union mask bits; checks })
  | (Every | Bits _), (Dirty Forced | Unmounted) -> ()

let mark_sourced instance bits =
  reading instance;
  instance.prepared <- Unprepared;
  match instance.status with
  | Clean ->
      sourced instance bits;
      dirty := instance :: !dirty
  | Dirty _ | Unmounted -> sourced instance bits

let changed_sources = ref Every

let unchanged = View.host ~build:(fun [@u] _ -> View.nothing) ~patch:(fun [@u] _ _ -> None)

let run_phases cleanups runs =
  let run_jobs phase jobs =
    List.iter
      (fun job ->
        let owner = match job with Effect hook -> hook.host | Work { owner; _ } -> owner in
        match owner.status with
        | Unmounted -> ()
        | Clean | Dirty _ -> (
            try
              match (job, phase) with
              | Effect hook, Cleanup -> finish hook
              | Effect hook, Run -> hook.cleanup <- hook.run ()
              | Work { work; _ }, (Cleanup | Run) -> work ()
            with error -> !suspension.rescue In_effect owner error [@u]))
      (List.rev jobs)
  in
  let pending_cleanups = !cleanups and pending_runs = !runs in
  cleanups := [];
  runs := [];
  run_jobs Cleanup pending_cleanups;
  run_jobs Run pending_runs

let render instance =
  instance.prepared <- Unprepared;
  let sources =
    match instance.status with
    | Dirty Forced | Clean | Unmounted -> Every
    | Dirty (Sourced { mask; checks }) ->
        List.fold_left
          (fun found (Checking (cell, check, bit)) -> match check cell with View.Changed -> union found bit | View.Unchanged -> found)
          mask checks
  in
  instance.status <- Clean;
  instance.renders <- instance.renders + 1;
  match instance.kind with
  | Renders definition ->
      let rec attempt count =
        Hook.rewind instance.slots;
        rerendering := Once;
        changed_sources := (match count with 1 -> sources | _ -> Every);
        let child = within rendering (Some instance) definition.render in
        changed_sources := Every;
        match (!rerendering, count < 25) with
        | Once, _ -> child
        | Again, true -> attempt (count + 1)
        | Again, false ->
            Js.Exn.raiseError "melact: too many re-renders: a component sets its own state on every render"
      in
      attempt 1
  | Provides provision -> provision.children
  | Suspends suspending -> suspending.wanted
  | Catches catching -> (
      match catching.failure with
      | Healthy | Caught _ | Struck _ -> catching.children
      | Failed error -> catching.recover error)

(** Whether an instance's write queued the effects of instances below it, which then come before its own. *)
type nesting = Alone | Nested

let held = ref []

let enqueue instance nesting =
  (match (!patching, instance.pending, nesting) with
  | At_once, _, _ | Next_round, [], Alone -> ()
  | Next_round, [], Nested -> join committed instance
  | Next_round, _ :: _, (Alone | Nested) ->
      let rec below ancestor =
        match ancestor with
        | None -> ()
        | Some above -> ( match member committed above with true -> put_off := Some_put_off | false -> below above.parent)
      in
      below instance.parent;
      join committed instance);
  (match instance.pending with [] -> () | _ :: _ -> incr enqueued);
  List.iter
    (fun job ->
      match job with
      | Effect { when_run = Layout; _ } ->
          layout_cleanups := job :: !layout_cleanups;
          layout_runs := job :: !layout_runs
      | Effect { when_run = Passive; _ } ->
          passive_cleanups := job :: !passive_cleanups;
          passive_runs := job :: !passive_runs
      | Work { timing = Layout; phase = Cleanup; _ } -> layout_cleanups := job :: !layout_cleanups
      | Work { timing = Layout; phase = Run; _ } -> layout_runs := job :: !layout_runs
      | Work { timing = Passive; phase = Cleanup; _ } -> passive_cleanups := job :: !passive_cleanups
      | Work { timing = Passive; phase = Run; _ } -> passive_runs := job :: !passive_runs)
    (List.rev instance.pending);
  instance.pending <- []

let commit ~since (position : Template.position) instance =
  (match (Js.Null.toOption (View.front instance.output Js.null), instance.region) with
  | Some _, Nodes | None, Marker _ -> ()
  | Some _, Marker node ->
      Dom_api.remove_child position.parent node;
      instance.region <- Nodes
  | None, Nodes ->
      let node = Dom_api.create_text_node Dom_api.document "" in
      View.insert position (Dom_api.to_node node);
      instance.region <- Marker node);
  let nesting = match !enqueued > since with true -> Nested | false -> Alone in
  match !deferral with
  | Deferring current when current == instance ->
      (match nesting with Nested -> join committed instance | Alone -> ());
      held := (instance, nesting) :: !held
  | Deferring _ | Queue_now -> enqueue instance nesting

let refresh (position : Template.position) instance =
  let at =
    match instance.region with
    | Marker node -> { position with before = Js.Null.return (Dom_api.to_node node) }
    | Nodes -> position
  in
  let since = !enqueued in
  match
    let child = render instance in
    match child == unchanged with
    | true -> instance.output
    | false -> within owner (Some instance) (fun () -> View.update at instance.output child)
  with
  | output ->
      instance.output <- output;
      commit ~since position instance
  | exception error ->
      instance.pending <- [];
      !suspension.rescue While_rendering instance error [@u]

let wrote (position : Template.position) instance rendered =
  let at =
    match instance.region with
    | Marker node -> { position with before = Js.Null.return (Dom_api.to_node node) }
    | Nodes -> position
  in
  let since = !enqueued in
  match
    match rendered with
    | Ok child when child == unchanged -> instance.output
    | Ok child -> within owner (Some instance) (fun () -> View.update at instance.output child)
    | Error error -> raise error
  with
  | output ->
      instance.output <- output;
      commit ~since position instance
  | exception error ->
      instance.pending <- [];
      !suspension.rescue While_rendering instance error [@u]

let rec settle () =
  let position_of instance =
    let last = ref None in
    visit_nodes instance (fun [@u] node -> last := Some node);
    match (Option.bind (Js.Null.toOption (front_node instance Js.null)) Dom_api.parent_node, !last) with
    | Some parent, Some last ->
        { Template.parent; before = Js.Null.fromOption (Dom_api.next_sibling last) }
    | None, _ | _, None -> Js.Exn.raiseError "melact: a mounted component is not in the DOM"
  in
  let rec drain () =
    match (!dirty, !layout_cleanups, !layout_runs, !recovery.outstanding () [@u], !suspension.outstanding () [@u]) with
    | [], [], [], Quiet, Quiet -> ()
    | _ ->
        !recovery.before_rendering () [@u];
        !suspension.before_rendering () [@u];
        let ordered pending = (let fronted = List.map (fun instance -> (Js.Null.toOption (front_node instance Js.null), instance)) pending in
           let by_depth = List.stable_sort (fun (_, a) (_, b) -> Int.compare a.depth b.depth) in
           match fronted with
           | [] | [ _ ] -> fronted
           | _ when List.compare_length_with fronted 16 <= 0 ->
               List.stable_sort
                 (fun (front_a, a) (front_b, b) ->
                   match (front_a, front_b) with
                   | Some first, Some second when not (Dom_api.same first second) ->
                       if Dom_api.compare_document_position first second land 4 <> 0 then -1 else 1
                   | Some _, Some _ | None, _ | _, None -> Int.compare a.depth b.depth)
                 fronted
           | (first, _) :: _ ->
               let placed = List.filter_map (fun (front, instance) -> Option.map (fun node -> (node, instance)) front) fronted in
               let unplaced = List.filter (fun (front, _) -> Option.is_none front) fronted in
               let starts = nodes_of () in
               let remaining = ref 0 in
               List.iter
                 (fun (node, instance) ->
                   match Js.Undefined.toOption (found_get starts node) with
                   | Some others -> found_set starts node (instance :: others)
                   | None ->
                       incr remaining;
                       found_set starts node [ instance ])
                 placed;
               let common first =
                 List.fold_left
                   (fun candidate (node, _) ->
                     let rec up candidate =
                       match node_contains candidate node with
                       | true -> Some candidate
                       | false -> Option.bind (Dom_api.parent_node candidate) up
                     in
                     Option.bind candidate up)
                   (Some first) placed
               in
               let walked = ref [] in
               let take node =
                 match Js.Undefined.toOption (found_get starts node) with
                 | None -> ()
                 | Some instances ->
                     walked := List.rev_append (by_depth (List.map (fun instance -> (Some node, instance)) instances)) !walked;
                     decr remaining;
                     found_delete starts node
               in
               Option.iter
                 (fun ancestor ->
                   take ancestor;
                   let walker = tree_walker Dom_api.document ancestor (-1) in
                   let rec next () =
                     match (!remaining, Js.Null.toOption (next_node walker)) with
                     | 0, _ | _, None -> ()
                     | _, Some node ->
                         take node;
                         next ()
                   in
                   next ())
                 (Option.bind first common);
               let missed = List.filter (fun (node, _) -> Js.Undefined.testAny (found_get starts node) |> not) placed in
               List.rev !walked @ by_depth (List.map (fun (node, instance) -> (Some node, instance)) missed) @ by_depth unplaced) in
        let queued = (!layout_cleanups, !layout_runs, !passive_cleanups, !passive_runs) in
        put_off := None_put_off;
        disband committed;
        let waiting = ref [] in
        let rec rendering round =
          let pending =
            match round with
            | `First -> !dirty
            | `Later ->
                let forced, stated =
                  List.partition
                    (fun instance ->
                      match instance.status with
                      | Dirty Forced -> true
                      | Dirty (Sourced { mask = Bits 0; _ }) -> false
                      | Dirty (Sourced _) -> true
                      | Clean | Unmounted -> false)
                    (!dirty @ !waiting)
                in
                waiting := stated;
                dirty := forced;
                forced
          in
          match pending with
          | [] -> ()
          | pending -> (
              dirty := [];
              reads := No_reads_ahead;
              List.iter reading !waiting;
              let unchanged checks =
                List.for_all
                  (fun (Checking (cell, check, _)) -> match check cell with View.Unchanged -> true | View.Changed -> false)
                  checks
              in
              match
                List.fold_left
                  (fun found instance ->
                    match (found, instance.kind) with
                    | Component.Pure, Renders { component = { rendering = Component.Pure; _ }; _ } -> Component.Pure
                    | (Component.Pure | Component.Impure), (Renders _ | Provides _ | Catches _ | Suspends _) -> Component.Impure)
                  Component.Pure pending
              with
              | Component.Pure ->
                  within patching Next_round (fun () ->
                      let rec released next =
                        match !held with
                        | [] -> ()
                        | (top, nesting) :: rest -> (
                            let rec under ancestor =
                              match ancestor with
                              | None -> `Elsewhere
                              | Some above -> ( match above == top with true -> `Under | false -> under above.parent)
                            in
                            match Option.fold ~none:`Elsewhere ~some:(fun next -> under next.parent) next with
                            | `Under -> ()
                            | `Elsewhere ->
                                held := rest;
                                enqueue top nesting;
                                released next)
                      in
                      List.iter
                        (fun (_, instance) ->
                          match instance.status with
                          | Dirty (Sourced { mask = Bits 0; checks }) when unchanged checks -> instance.status <- Clean
                          | Dirty (Forced | Sourced _) -> (
                              released (Some instance);
                              let result = match render instance with child -> Ok child | exception error -> Error error in
                              match instance.status with
                              | Unmounted -> ()
                              | Clean | Dirty _ -> within deferral (Deferring instance) (fun () -> wrote (position_of instance) instance result))
                          | Clean | Unmounted -> ())
                        (ordered
                           (List.filter
                              (fun instance -> match instance.status with Dirty _ -> true | Clean | Unmounted -> false)
                              pending));
                      released None);
                  rendering `Later
              | Component.Impure ->
              let round = audience () in
              List.iter
                (fun instance -> match instance.status with Dirty _ -> join round instance | Clean | Unmounted -> ())
                pending;
              let topmost instance =
                let rec up ancestor =
                  match ancestor with
                  | None -> `Topmost
                  | Some above -> ( match member round above with true -> `Under_dirty | false -> up above.parent)
                in
                up instance.parent
              in
              let roots, later =
                List.partition
                  (fun instance ->
                    match (instance.status, topmost instance) with Dirty _, `Topmost -> true | (Dirty _ | Clean | Unmounted), _ -> false)
                  pending
              in
              List.iter reading later;
              let roots = ordered roots in
              let rendered =
                List.filter_map
                  (fun (_, instance) ->
                    match instance.status with
                    | Dirty (Sourced { mask = Bits 0; checks }) when unchanged checks ->
                        instance.status <- Clean;
                        None
                    | Dirty (Forced | Sourced _) ->
                        Some
                          ( instance,
                            match instance.prepared with
                            | Prepared result ->
                                instance.prepared <- Unprepared;
                                instance.status <- Clean;
                                result
                            | Unprepared -> ( match render instance with child -> Ok child | exception error -> Error error) )
                    | Clean | Unmounted -> None)
                  roots
              in
              within patching Next_round (fun () ->
                  List.iter
                    (fun (instance, result) ->
                      match instance.status with
                      | Unmounted -> ()
                      | Clean | Dirty _ -> wrote (position_of instance) instance result)
                    rendered);
              dirty :=
                List.filter (fun instance -> match instance.status with Dirty _ -> true | Clean | Unmounted -> false) later
                @ !dirty;
              rendering `Later)
        in
        rendering `First;
        dirty := !waiting @ !dirty;
        (match !put_off with
        | None_put_off -> ()
        | Some_put_off ->
            let host job = match job with Effect hook -> hook.host | Work { owner; _ } -> owner in
            let ending job =
              let last = ref None in
              visit_nodes (host job) (fun [@u] node -> last := Some node);
              let rec deepest node = Option.fold ~none:node ~some:deepest (Js.Null.toOption (Dom_api.last_child node)) in
              Option.map deepest !last
            in
            let rec fresh old list oldest_first =
              match list == old with
              | true -> oldest_first
              | false -> ( match list with job :: rest -> fresh old rest (job :: oldest_first) | [] -> oldest_first)
            in
            let old_layout_cleanups, old_layout_runs, old_passive_cleanups, old_passive_runs = queued in
            let batches =
              List.map
                (fun (queue, old) -> (queue, old, List.map (fun job -> (job, ending job, (host job).depth)) (fresh old !queue [])))
                [
                  (layout_cleanups, old_layout_cleanups);
                  (layout_runs, old_layout_runs);
                  (passive_cleanups, old_passive_cleanups);
                  (passive_runs, old_passive_runs);
                ]
            in
            let endings = List.concat_map (fun (_, _, jobs) -> List.filter_map (fun (_, last, _) -> last) jobs) batches in
            let earlier =
              match List.compare_length_with endings 32 <= 0 with
              | true -> (
                  fun first second ->
                    match (first, second) with
                    | Some first, Some second when not (Dom_api.same first second) ->
                        if Dom_api.compare_document_position first second land 4 <> 0 then -1 else 1
                    | Some _, Some _ | None, None -> 0
                    | Some _, None -> -1
                    | None, Some _ -> 1)
              | false ->
                  let ranks = nodes_ranked () in
                  let remaining = ref 0 in
                  List.iter
                    (fun node ->
                      match Js.Undefined.toOption (rank_get ranks node) with
                      | Some _ -> ()
                      | None ->
                          incr remaining;
                          rank_set ranks node (-1))
                    endings;
                  let common =
                    List.fold_left
                      (fun candidate node ->
                        let rec up candidate =
                          match node_contains candidate node with
                          | true -> Some candidate
                          | false -> Option.bind (Dom_api.parent_node candidate) up
                        in
                        Option.bind candidate up)
                      (Some (List.hd endings)) endings
                  in
                  let count = ref 0 in
                  let mark node =
                    (match Js.Undefined.toOption (rank_get ranks node) with
                    | Some _ ->
                        rank_set ranks node !count;
                        decr remaining
                    | None -> ());
                    incr count
                  in
                  Option.iter
                    (fun ancestor ->
                      mark ancestor;
                      let walker = tree_walker Dom_api.document ancestor (-1) in
                      let rec next () =
                        match (!remaining, Js.Null.toOption (next_node walker)) with
                        | 0, _ | _, None -> ()
                        | _, Some node ->
                            mark node;
                            next ()
                      in
                      next ())
                    common;
                  let rank last =
                    Option.fold ~none:max_int
                      ~some:(fun node ->
                        Option.fold ~none:max_int
                          ~some:(fun rank -> match rank < 0 with true -> max_int | false -> rank)
                          (Js.Undefined.toOption (rank_get ranks node)))
                      last
                  in
                  fun first second -> Int.compare (rank first) (rank second)
            in
            List.iter
              (fun (queue, old, jobs) ->
                match jobs with
                | [] | [ _ ] -> ()
                | _ :: _ :: _ ->
                    let ordered =
                      List.stable_sort
                        (fun (first_job, first, first_depth) (second_job, second, second_depth) ->
                          match Option.fold ~none:0 ~some:(fun order -> order (host first_job) (host second_job)) !tree_order with
                          | 0 -> (
                              match earlier first second with
                              | 0 -> Int.compare second_depth first_depth
                              | order -> order)
                          | order -> order)
                        jobs
                    in
                    queue := List.rev_append (List.map (fun (job, _, _) -> job) ordered) old)
              batches);
        disband committed;
        View.attach_references ();
        !recovery.after_rendering () [@u];
        !suspension.after_rendering () [@u];
        run_phases layout_cleanups layout_runs;
        (match (!recovery.outstanding () [@u], !suspension.outstanding () [@u], !dirty) with
        | Quiet, Quiet, [] -> ()
        | Quiet, Quiet, _ :: _ | Busy, _, _ | _, Busy, _ -> run_phases passive_cleanups passive_runs);
        drain ()
  in
  drain ();
  match (!passive_cleanups, !passive_runs, !passive_schedule) with
  | [], [], _ | _, _, Queued -> ()
  | _ :: _, _, Idle | _, _ :: _, Idle ->
      passive_schedule := Queued;
      Dom_api.request_animation_frame (fun _ -> Dom_api.set_timeout run_passive 0)

and run_passive () =
  passive_schedule := Idle;
  run_phases passive_cleanups passive_runs;
  match (!recovery.outstanding () [@u], !suspension.outstanding () [@u]) with
  | Quiet, Quiet -> ()
  | Busy, _ | _, Busy -> settle ()

let flush () =
  render_schedule := Unqueued;
  settle ();
  run_passive ()

let () = Events.after_controlled := flush

let deferred = ref []

let rec defer job =
  (match !deferred with [] -> Dom_api.set_timeout (fun () -> ignore (run_deferred ())) 0 | _ :: _ -> ());
  deferred := job :: !deferred

and run_deferred () =
  match List.rev !deferred with
  | [] -> `Idle
  | jobs ->
      deferred := [];
      List.iter (fun job -> job ()) jobs;
      `Ran

let position = ref Melhole_server.Tree.root
let around = ref []

let () =
  View.positions :=
    {
      fork =
        (fun [@u] count index ->
          around := !position :: !around;
          position := Melhole_server.Tree.pushed !position count index);
      join =
        (fun [@u] () ->
          match !around with
          | outer :: rest ->
              position := outer;
              around := rest
          | [] -> ());
    }

let number_from_root () =
  position := Melhole_server.Tree.root;
  around := []

let counted = ref 0

let id instance =
  let local = instance.ids in
  instance.ids <- local + 1;
  match instance.tree with
  | Numbered tree -> Melhole_server.Tree.id tree local
  | Unnumbered ->
      incr counted;
      ":m" ^ string_of_int !counted ^ ":"

let born kind =
  let instance =
    {
      parent = !owner;
      depth = Option.fold ~none:0 ~some:(fun parent -> parent.depth + 1) !owner;
      tree = (match !View.medium.adoption with View.Server_nodes -> Numbered !position | View.Fresh_nodes -> Unnumbered);
      ids = 0;
      slots = Hook.slots ();
      kind;
      status = Clean;
      output = View.nothing;
      region = Nodes;
      pending = [];
      teardown = [];
      renders = 0;
      providers = [];
      prepared = Unprepared;
    }
  in
  instance

(** Siblings that one patch builds from the last one: where the last of them went, and the effect
    queues below the first of them and above the last. *)
type 'job siblings = {
  parent : Dom.node;
  mutable front : Dom.node Js.null;
  base : 'job list * 'job list * 'job list * 'job list;
  mutable above : 'job list * 'job list * 'job list * 'job list;
}

let siblings : job siblings option ref = ref None

let mount_instance position kind =
  let instance = born kind in
  let since = !enqueued in
  let queued () = (!layout_cleanups, !layout_runs, !passive_cleanups, !passive_runs) in
  let before = match (!View.patch_order, !mounting) with View.Out_of_order, 0 -> Some (queued ()) | _ -> None in
  incr mounting;
  (match
     let child = render instance in
     within owner (Some instance) (fun () ->
         match (instance.tree, instance.ids) with
         | Numbered _, 0 | Unnumbered, _ -> View.build child position
         | Numbered _, _ ->
             !View.positions.fork 1 0 [@u];
             let built = View.build child position in
             !View.positions.join () [@u];
             built)
   with
  | output ->
      instance.output <- output;
      commit ~since position instance;
      decr mounting
  | exception error ->
      instance.pending <- [];
      commit ~since position instance;
      decr mounting;
      !suspension.rescue While_rendering instance error [@u]);
  let live = View.live instances instance in
  (match (before, !enqueued > since) with
  | Some before, true -> (
      let front = View.front live Js.null in
      let rec above stop list = match list == stop with true -> [] | false -> ( match list with job :: rest -> job :: above stop rest | [] -> []) in
      match !siblings with
      | Some ({ above = a1, a2, a3, a4; _ } as run)
        when Dom_api.same run.parent position.parent
             && (let e1, e2, e3, e4 = before in a1 == e1 && a2 == e2 && a3 == e3 && a4 == e4)
             &&
             let rec reaches node =
               match Js.Null.toOption node with
               | None -> `Elsewhere
               | Some node when Dom_api.same (Js.Null.return node) run.front -> `Before_it
               | Some node -> reaches (Dom_api.following_sibling node)
             in
             reaches position.before = `Before_it ->
          let b1, b2, b3, b4 = run.base and e1, e2, e3, e4 = before in
          let splice queue base earlier = queue := above base earlier @ above earlier !queue @ base in
          splice layout_cleanups b1 e1;
          splice layout_runs b2 e2;
          splice passive_cleanups b3 e3;
          splice passive_runs b4 e4;
          run.front <- front;
          run.above <- queued ()
      | Some _ | None -> siblings := Some { parent = position.parent; front; base = before; above = queued () })
  | (Some _ | None), _ -> ());
  live

let component definition inputs render =
  View.host
    ~build:(fun [@u] position -> mount_instance position (Renders { component = definition; inputs; render }))
    ~patch:
      (fun [@u] position live ->
        match View.hosted instances live with
        | Some instance -> (
            match instance.kind with
            | Renders rendered when Dom_api.same rendered.component definition ->
                (match (instance.status, View.compare_inputs rendered.inputs inputs) with
                | Clean, View.Unchanged -> ()
                | (Clean | Dirty _ | Unmounted), _ -> (
                    let bits =
                      match Array.length inputs = Array.length rendered.inputs && Array.length inputs < 30 with
                      | false -> Every
                      | true ->
                          let found = ref 0 in
                          Array.iteri
                            (fun index (View.Input next) ->
                              let (View.Input last) = Array.unsafe_get rendered.inputs index in
                              if not (Dom_api.same last next) then found := !found lor (1 lsl index))
                            inputs;
                          Bits !found
                    in
                    rendered.inputs <- inputs;
                    rendered.render <- render;
                    match (!patching, instance.status, definition.rendering, !View.patch_order, !reads) with
                    | Next_round, (Clean | Dirty _), Component.Impure, _, _
                    | Next_round, (Clean | Dirty _), _, View.Out_of_order, _
                    | Next_round, (Clean | Dirty _), _, _, Reads_ahead ->
                        put_off := Some_put_off;
                        mark_sourced instance bits
                    | (At_once | Next_round), _, (Component.Pure | Component.Impure), _, _ ->
                        sourced instance bits;
                        refresh position instance));
                Some live
            | Renders _ | Provides _ | Catches _ | Suspends _ -> None)
        | None -> None)

let provide : type value. value Context.t -> value -> View.child -> View.child =
 fun context value children ->
  View.host
    ~build:(fun [@u] position ->
      mount_instance position (Provides { context; value; children; consumers = readers (); known = audience () }))
    ~patch:
      (fun [@u] position live ->
        match View.hosted instances live with
        | Some instance -> (
            match instance.kind with
            | Provides provision -> (
                match Type.Id.provably_equal provision.context.witness context.witness with
                | Some Equal ->
                    if not (Dom_api.same provision.value value) then (
                      provision.value <- value;
                      let marked = ref [] in
                      each_reader provision.consumers (fun bits reader ->
                          mark_sourced reader bits;
                          marked := reader :: !marked);
                      clear_readers provision.consumers;
                      match !patching with
                      | At_once -> ()
                      | Next_round ->
                          List.iter
                            (fun reader ->
                              match (reader.kind, reader.status) with
                              | Renders { component = { rendering = Component.Impure; _ }; _ }, Dirty _ ->
                                  let result = match render reader with child -> Ok child | exception error -> Error error in
                                  reader.status <- Dirty Forced;
                                  reader.prepared <- Prepared result
                              | (Renders _ | Provides _ | Catches _ | Suspends _), (Clean | Dirty _ | Unmounted) -> ())
                            (List.rev !marked));
                    provision.children <- children;
                    refresh position instance;
                    Some live
                | None -> None)
            | Renders _ | Catches _ | Suspends _ -> None)
        | None -> None)

let writing_component () =
  let named instance = match instance.kind with Renders { component; _ } -> Some component.name | Provides _ | Catches _ | Suspends _ -> None in
  match !rendering with Some instance -> named instance | None -> Option.bind !owner named

let current () =
  match !rendering with
  | Some instance -> instance
  | None -> Js.Exn.raiseError "melact: hooks can only be called while a component renders"

let slot instance key init = Hook.take instance.slots key init

let lane () =
  Option.fold ~none:`Default
    ~some:(fun event ->
      match Dom_api.event_type event with
      | "auxclick" | "beforeinput" | "blur" | "cancel" | "change" | "click" | "close" | "compositionend"
      | "compositionstart" | "compositionupdate" | "contextmenu" | "copy" | "cut" | "dblclick" | "dragend"
      | "dragstart" | "drop" | "focus" | "focusin" | "focusout" | "fullscreenchange" | "hashchange" | "input"
      | "invalid" | "keydown" | "keypress" | "keyup" | "mousedown" | "mouseup" | "paste" | "pause" | "play"
      | "pointercancel" | "pointerdown" | "pointerup" | "popstate" | "ratechange" | "reset" | "resize" | "seeked"
      | "select" | "selectionchange" | "selectstart" | "submit" | "textInput" | "touchcancel" | "touchend"
      | "touchstart" | "volumechange" ->
          `Discrete
      | _ -> `Default)
    (Js.Undefined.toOption Dom_api.current_event)

let queue_render () =
  match (!render_schedule, lane ()) with
  | Next_microtask, _ | Next_task, `Default -> ()
  | (Unqueued | Next_task), `Discrete ->
      render_schedule := Next_microtask;
      Dom_api.queue_microtask flush
  | Unqueued, `Default ->
      render_schedule := Next_task;
      Dom_api.set_timeout
        (fun () ->
          render_schedule := Unqueued;
          settle ())
        0

let settle_in_event () =
  settle ();
  match lane () with `Discrete -> Dom_api.queue_microtask run_passive | `Default -> ()

let invalidate instance =
  match !rendering with
  | Some current when current == instance -> rerendering := Again
  | Some _ ->
      Js.Exn.raiseError "melact: a state setter was called while a component was rendering"
  | None ->
      mark_dirty instance;
      queue_render ()

let invalidate_state instance cell check bit =
  match !rendering with
  | Some current when current == instance -> rerendering := Again
  | Some _ ->
      Js.Exn.raiseError "melact: a state setter was called while a component was rendering"
  | None ->
      reading instance;
      instance.prepared <- Unprepared;
      (match instance.status with
      | Clean ->
          instance.status <- Dirty (Sourced { mask = Bits 0; checks = [ Checking (cell, check, bit) ] });
          dirty := instance :: !dirty
      | Dirty (Sourced { mask; checks }) -> instance.status <- Dirty (Sourced { mask; checks = Checking (cell, check, bit) :: checks })
      | Dirty Forced | Unmounted -> ());
      queue_render ()

let cell_source instance =
  match instance.kind with
  | Renders { inputs; _ } -> (
      let at = Array.length inputs + Hook.position instance.slots in
      match at < 30 with true -> Bits (1 lsl at) | false -> Every)
  | Provides _ | Catches _ | Suspends _ -> Every

let changed () = !changed_sources
let skip_hook () = match !rendering with Some instance -> Hook.skip instance.slots | None -> ()

let after_commit instance timing phase work =
  instance.pending <- Work { owner = instance; timing; phase; work } :: instance.pending

let start_effect instance timing deps run =
  let made = { host = instance; when_run = timing; deps; cleanup = None; run; queued_in = instance.renders } in
  instance.teardown <- Finishes made :: instance.teardown;
  instance.pending <- Effect made :: instance.pending;
  made

let deps hook = hook.deps

let rerun hook deps run =
  hook.deps <- deps;
  hook.run <- run;
  match hook.queued_in = hook.host.renders with
  | true -> ()
  | false ->
      hook.queued_in <- hook.host.renders;
      hook.host.pending <- Effect hook :: hook.host.pending

let queued hook = match hook.queued_in = hook.host.renders with true -> `This_render | false -> `Earlier
let found instance key = Hook.found instance.slots key
let put instance key value = Hook.put instance.slots key value

let on_unmount instance cleanup = instance.teardown <- Calls cleanup :: instance.teardown

let rec provided : type value. instance -> sources -> value Context.t -> instance option -> value =
 fun instance bits context ancestor ->
  match ancestor with
  | None -> context.default
  | Some above -> (
      match above.kind with
      | Provides provision when Dom_api.same provision.context.witness context.witness -> (
          match Type.Id.provably_equal provision.context.witness context.witness with
          | Some Equal ->
              if not (member provision.known instance) then (
                join provision.known instance;
                instance.teardown <-
                  Leaves { consumers = provision.consumers; known = provision.known } :: instance.teardown);
              instance.providers <- above :: instance.providers;
              read provision.consumers instance bits;
              provision.value
          | None -> provided instance bits context above.parent)
      | Provides _ | Renders _ | Catches _ | Suspends _ -> provided instance bits context above.parent)

let consume_source : type value. instance -> sources -> value Context.t -> value =
 fun instance bits context ->
  let rec known providers =
    match providers with
    | [] -> provided instance bits context instance.parent
    | { kind = Provides provision; _ } :: rest when Dom_api.same provision.context.witness context.witness -> (
        match Type.Id.provably_equal provision.context.witness context.witness with
        | Some Equal ->
            read provision.consumers instance bits;
            provision.value
        | None -> known rest)
    | { kind = Provides _ | Renders _ | Catches _ | Suspends _; _ } :: rest -> known rest
  in
  known instance.providers

let consume instance context = consume_source instance Every context

let catch =
  let caught_boundaries = ref [] and struck_boundaries = ref [] and fallen_boundaries = ref [] in
  let record stage instance error =
    View.forget instance.output;
    let caught = match error with Js.Exn.Error raw -> caught_of raw | other -> caught_of other in
    let rec find ancestor =
      match ancestor with
      | None -> thrown error
      | Some ({ kind = Catches catching; _ } as boundary) -> (
          match (catching.failure, stage) with
          | Failed _, _ -> find boundary.parent
          | Healthy, While_rendering | Struck _, While_rendering ->
              caught_boundaries := boundary :: !caught_boundaries;
              catching.failure <- Caught { error = caught; thrower = instance }
          | Caught { thrower; _ }, While_rendering -> (
              let front instance =
                match instance.kind with
                | Catches { start; _ } -> Some (Dom_api.to_node start)
                | Suspends { opening; _ } -> Some (Dom_api.to_node opening)
                | Renders _ | Provides _ -> Js.Null.toOption (front_node instance Js.null)
              in
              match (front thrower, front instance) with
              | Some kept, Some thrown when Dom_api.compare_document_position kept thrown land 4 = 0 -> ()
              | Some _, Some _ | None, _ | _, None -> catching.failure <- Caught { error = caught; thrower = instance })
          | Healthy, In_effect ->
              struck_boundaries := boundary :: !struck_boundaries;
              catching.failure <- Struck caught
          | Struck _, In_effect -> catching.failure <- Struck caught
          | Caught _, In_effect -> ())
      | Some above -> find above.parent
    in
    find instance.parent
  in
  let blank boundary (catching : catching) =
    let finish = Dom_api.to_node catching.finish in
    let rec clear node =
      match Js.Null.toOption node with
      | Some found when not (Dom_api.same found finish) ->
          let next = Dom_api.following_sibling found in
          Option.iter (fun parent -> Dom_api.remove_child parent found) (Dom_api.parent_node found);
          clear next
      | Some _ | None -> ()
    in
    View.release boundary.output;
    boundary.output <- View.nothing;
    clear (Dom_api.following_sibling (Dom_api.to_node catching.start))
  in
  let taken list =
    let boundaries = !list in
    list := [];
    boundaries
  in
  let installed =
    {
      rescue = (fun [@u] stage instance error -> record stage instance error);
      before_rendering =
        (fun [@u] () ->
          List.iter
            (fun boundary ->
              match boundary with
              | { status = Clean | Dirty _; kind = Catches ({ failure = Struck error; _ } as catching); _ } ->
                  blank boundary catching;
                  catching.failure <- Caught { error; thrower = boundary };
                  caught_boundaries := boundary :: !caught_boundaries
              | _ -> ())
            (taken struck_boundaries);
          List.iter
            (fun boundary ->
              match boundary with
              | { status = Clean | Dirty _; kind = Catches ({ failure = Failed _; _ } as catching); _ } -> (
                  let finish = Dom_api.to_node catching.finish in
                  blank boundary catching;
                  let inside = { Template.parent = Option.get (Dom_api.parent_node finish); before = Js.Null.return finish } in
                  match within owner (Some boundary) (fun () -> View.build (render boundary) inside) with
                  | live -> boundary.output <- live
                  | exception error -> record While_rendering boundary error)
              | _ -> ())
            (taken fallen_boundaries));
      after_rendering =
        (fun [@u] () ->
          List.iter
            (fun boundary ->
              match boundary with
              | { status = Clean | Dirty _; kind = Catches ({ failure = Caught { error; _ }; _ } as catching); _ } ->
                  blank boundary catching;
                  catching.failure <- Failed error;
                  fallen_boundaries := boundary :: !fallen_boundaries
              | _ -> ())
            (taken caught_boundaries));
      outstanding =
        (fun [@u] () ->
          match (!caught_boundaries, !struck_boundaries, !fallen_boundaries) with
          | [], [], [] -> Quiet
          | _ :: _, _, _ | _, _ :: _, _ | _, _, _ :: _ -> Busy);
    }
  in
  fun ~recover children ->
    View.host
      ~build:(fun [@u] (position : Template.position) ->
        recovery := installed;
        let start = !View.medium.text position None [@u] in
        let finish = Dom_api.create_text_node Dom_api.document "" in
        let catching = { children; recover; failure = Healthy; start; finish } in
        let boundary = born (Catches catching) in
        (match !View.medium.adoption with
        | View.Fresh_nodes ->
            Dom_api.insert_before position.parent (Dom_api.to_node finish) position.before;
            boundary.output <-
              within owner (Some boundary) (fun () ->
                  View.build (render boundary) { position with before = Js.Null.return (Dom_api.to_node finish) })
        | View.Server_nodes ->
            boundary.output <- within owner (Some boundary) (fun () -> View.build (render boundary) position);
            let last = ref (Dom_api.to_node start) in
            View.visit boundary.output (fun [@u] node -> last := node);
            Dom_api.insert_before position.parent (Dom_api.to_node finish) (Dom_api.following_sibling !last));
        View.live instances boundary)
      ~patch:(fun [@u] _ live ->
        match View.hosted instances live with
        | Some ({ kind = Catches catching; _ } as boundary) ->
            catching.children <- children;
            let finish = Dom_api.to_node catching.finish in
            (match catching.failure with
            | Caught _ -> ()
            | Healthy | Struck _ | Failed _ -> (
            match
               within owner (Some boundary) (fun () ->
                   View.update
                     { Template.parent = Option.get (Dom_api.parent_node finish); before = Js.Null.return finish }
                     boundary.output (render boundary))
             with
            | output -> boundary.output <- output
            | exception error -> record While_rendering boundary error));
            Some live
        | Some _ | None -> None)

let suspend =
  let suspended = ref [] and retried = ref [] and fresh = ref [] in
  let nodes (live : View.live) =
    let found = ref [] in
    View.visit live (fun [@u] node -> found := node :: !found);
    List.rev !found
  in
  let removed (live : View.live) =
    let gone = nodes live in
    View.release live;
    List.iter (fun node -> Option.iter (fun parent -> Dom_api.remove_child parent node) (Dom_api.parent_node node)) gone
  in
  let hidden_nodes (live : View.live) =
    List.filter_map
      (fun node ->
        match Dom_api.node_type node with
        | 1 ->
            let style = Dom_api.style (Dom_api.unsafe_element node) in
            let shown = Dom_api.style_property style "display" in
            Dom_api.set_style_property style "display" "none" "important";
            Some (node, Displayed shown)
        | 3 ->
            let text = Dom_api.data node in
            Dom_api.set_data (Dom_api.unsafe_text node) "";
            Some (node, Texted text)
        | _ -> None)
      (nodes live)
  in
  let shown_again hidden =
    List.iter
      (fun (node, look) ->
        match look with
        | Displayed "" -> Dom_api.remove_style_property (Dom_api.style (Dom_api.unsafe_element node)) "display"
        | Displayed shown -> Dom_api.set_style_property (Dom_api.style (Dom_api.unsafe_element node)) "display" shown ""
        | Texted text -> Dom_api.set_data (Dom_api.unsafe_text node) text)
      hidden
  in
  let inside (suspending : suspending) =
    let closing = Dom_api.to_node suspending.closing in
    { Template.parent = Option.get (Dom_api.parent_node closing); before = Js.Null.return closing }
  in
  let installed =
    {
      rescue =
        (fun [@u] stage instance error ->
          match error with
          | Suspended promise ->
              View.forget instance.output;
              let rec find ancestor =
                match ancestor with
                | None -> !recovery.rescue stage instance error [@u]
                | Some ({ kind = Suspends ({ waiting = Showing | Retrying _; _ } as suspending); _ } as boundary) ->
                    suspended := boundary :: !suspended;
                    suspending.waiting <- Suspending { promise; throwers = [ instance ] }
                | Some { kind = Suspends ({ waiting = Suspending { promise; throwers }; _ } as suspending); _ } ->
                    suspending.waiting <- Suspending { promise; throwers = instance :: throwers }
                | Some above -> find above.parent
              in
              find instance.parent
          | other -> !recovery.rescue stage instance other [@u]);
      before_rendering =
        (fun [@u] () ->
          let ready = !retried in
          retried := [];
          List.iter
            (fun boundary ->
              match boundary with
              | { status = Clean | Dirty _; kind = Suspends ({ waiting = Retrying { content; throwers }; _ } as suspending); _ }
                -> (
                  removed suspending.backup;
                  suspending.backup <- View.nothing;
                  suspending.waiting <- Showing;
                  match content with
                  | Absent ->
                      fresh := boundary :: !fresh;
                      suspending.content <-
                        within owner (Some boundary) (fun () -> View.build suspending.wanted (inside suspending))
                  | Hidden hidden ->
                      shown_again hidden;
                      List.iter mark_dirty throwers;
                      suspending.content <-
                        within owner (Some boundary) (fun () ->
                            View.update (inside suspending) suspending.content suspending.wanted))
              | _ -> ())
            ready);
      after_rendering =
        (fun [@u] () ->
          let caught = !suspended and built = !fresh in
          suspended := [];
          fresh := [];
          List.iter
            (fun boundary ->
              match boundary with
              | { status = Clean | Dirty _; kind = Suspends ({ waiting = Suspending { promise; throwers }; _ } as suspending); _ }
                ->
                  let content =
                    match List.memq boundary built with
                    | true ->
                        View.release suspending.content;
                        suspending.content <- View.nothing;
                        let closing = Dom_api.to_node suspending.closing in
                        let rec clear node =
                          match Js.Null.toOption node with
                          | Some found when not (Dom_api.same found closing) ->
                              let next = Dom_api.following_sibling found in
                              Option.iter (fun parent -> Dom_api.remove_child parent found) (Dom_api.parent_node found);
                              clear next
                          | Some _ | None -> ()
                        in
                        clear (Dom_api.following_sibling (Dom_api.to_node suspending.opening));
                        Absent
                    | false -> Hidden (hidden_nodes suspending.content)
                  in
                  suspending.waiting <- Waiting { content; throwers };
                  suspending.backup <-
                    within owner (Some boundary) (fun () -> View.build suspending.fallback (inside suspending));
                  let settled () =
                    match suspending.waiting with
                    | Waiting { content; throwers } when boundary.status != Unmounted ->
                        suspending.waiting <- Retrying { content; throwers };
                        retried := boundary :: !retried;
                        queue_render ()
                    | _ -> ()
                  in
                  ([%mel.raw
                     "function (promise, settled) { var later = function () { queueMicrotask(settled); }; promise.then(later, later); }"]
                    : thenable -> (unit -> unit) -> unit)
                    promise settled
              | _ -> ())
            caught);
      outstanding =
        (fun [@u] () ->
          match (!suspended, !retried, !fresh) with
          | [], [], [] -> Quiet
          | _ -> Busy);
    }
  in
  let marker data node =
    Option.bind (Js.Null.toOption node) (fun found ->
        match (Dom_api.node_type found, Dom_api.data found) with
        | 8, given when String.equal given data -> Some found
        | _ -> None)
  in
  let rec dropped parent node depth =
    match Js.Null.toOption node with
    | None -> node
    | Some found -> (
        let next = Dom_api.following_sibling found in
        let depth =
          match (Dom_api.node_type found, Dom_api.data found) with
          | 8, ("$" | "$!" | "$?") -> depth + 1
          | 8, "/$" -> depth - 1
          | _ -> depth
        in
        Dom_api.remove_child parent found;
        match depth with 0 -> next | _ -> dropped parent next depth)
  in
  fun ~fallback children ->
    View.host
      ~build:(fun [@u] (position : Template.position) ->
        suspension := installed;
        let position, server =
          match (!View.medium.adoption, marker "$" position.before, marker "$!" position.before) with
          | View.Server_nodes, Some opened, _ ->
              let next = Dom_api.following_sibling opened in
              Dom_api.remove_child position.parent opened;
              ({ position with before = next }, `Rendered)
          | View.Server_nodes, None, Some _ ->
              ({ position with before = dropped position.parent position.before 0 }, `Left_to_client)
          | (View.Server_nodes | View.Fresh_nodes), _, _ -> (position, `Rendered)
        in
        let opening = !View.medium.text position None [@u] in
        let closing = Dom_api.create_text_node Dom_api.document "" in
        let suspending =
          { wanted = children; fallback; waiting = Showing; content = View.nothing; backup = View.nothing; opening; closing }
        in
        let boundary = born (Suspends suspending) in
        fresh := boundary :: !fresh;
        (match !View.medium.adoption with
        | View.Fresh_nodes ->
            Dom_api.insert_before position.parent (Dom_api.to_node closing) position.before;
            suspending.content <-
              within owner (Some boundary) (fun () ->
                  View.build children { position with before = Js.Null.return (Dom_api.to_node closing) })
        | View.Server_nodes -> (
            match server with
            | `Left_to_client ->
                Dom_api.insert_before position.parent (Dom_api.to_node closing) position.before;
                suspending.content <-
                  !View.medium.aside (fun [@u] () ->
                      within owner (Some boundary) (fun () ->
                          View.build children { position with before = Js.Null.return (Dom_api.to_node closing) }))
                  [@u]
            | `Rendered ->
                suspending.content <- within owner (Some boundary) (fun () -> View.build children position);
                let last = ref (Dom_api.to_node opening) in
                View.visit suspending.content (fun [@u] node -> last := node);
                let after = Dom_api.following_sibling !last in
                Dom_api.insert_before position.parent (Dom_api.to_node closing)
                  (Option.fold ~none:after
                     ~some:(fun closed ->
                       let next = Dom_api.following_sibling closed in
                       Dom_api.remove_child position.parent closed;
                       next)
                     (marker "/$" after))));
        View.live instances boundary)
      ~patch:(fun [@u] _ live ->
        match View.hosted instances live with
        | Some ({ kind = Suspends suspending; _ } as boundary) ->
            suspending.wanted <- children;
            suspending.fallback <- fallback;
            (match suspending.waiting with
            | Showing | Suspending _ ->
                suspending.content <-
                  within owner (Some boundary) (fun () -> View.update (inside suspending) suspending.content children)
            | Waiting { content; throwers } ->
                suspending.waiting <- Retrying { content; throwers };
                retried := boundary :: !retried;
                suspending.backup <-
                  within owner (Some boundary) (fun () -> View.update (inside suspending) suspending.backup fallback)
            | Retrying _ ->
                suspending.backup <-
                  within owner (Some boundary) (fun () -> View.update (inside suspending) suspending.backup fallback));
            Some live
        | Some _ | None -> None)
