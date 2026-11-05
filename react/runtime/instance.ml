open Melhole

(** When an effect runs after its instance is patched. *)
type timing =
  | Layout  (** Synchronously, before the browser paints. *)
  | Passive  (** After the whole flush, once the browser has painted. *)

(** Within one commit every cleanup runs before any effect, as in React. *)
type phase = Cleanup | Run

(** A mounted component: its hook slots, its output and its effects. *)
type instance = {
  parent : instance option;  (** The nearest enclosing instance. *)
  depth : int;
  slots : Hook.slots;
  kind : kind;
  mutable status : status;
  mutable output : View.live;
  mutable region : region;
  mutable pending : (timing * phase * (unit -> unit)) list;  (** Effects of the last render, newest first. *)
  mutable teardown : (unit -> unit) list;  (** Run on unmount, newest first. *)
}

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
      mutable consumers : instance list;
    }
      -> kind

and status = Clean | Dirty | Unmounted

(** Where an instance sits in the DOM when its output has no nodes. *)
and region =
  | Nodes  (** The output's own nodes locate it. *)
  | Marker of Dom.text  (** An empty text node holds its place. *)

type View.hosted += Instance of instance

(** Whether a flush is already queued. *)
type schedule = Idle | Queued

let rendering = ref None
let owner = ref None
let dirty = ref []
let layout_cleanups = ref []
let layout_runs = ref []
let passive_cleanups = ref []
let passive_runs = ref []
let render_schedule = ref Idle
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

let mark_dirty instance =
  match instance.status with
  | Clean ->
      instance.status <- Dirty;
      dirty := instance :: !dirty
  | Dirty | Unmounted -> ()

let run_phases cleanups runs =
  let run_jobs jobs =
    List.iter
      (fun (instance, job) ->
        match instance.status with Unmounted -> () | Clean | Dirty -> job ())
      (List.rev jobs)
  in
  let pending_cleanups = !cleanups and pending_runs = !runs in
  cleanups := [];
  runs := [];
  run_jobs pending_cleanups;
  run_jobs pending_runs

let run_passive () =
  passive_schedule := Idle;
  run_phases passive_cleanups passive_runs

let instance_live instance =
  View.live (Instance instance)
    ~each:
      (fun [@u] visit ->
        instance.output.each visit [@u];
        match instance.region with
        | Marker node -> visit (Dom_api.to_node node) [@u]
        | Nodes -> ())
    ~front:
      (fun [@u] after ->
        instance.output.front
          (match instance.region with
          | Marker node -> Js.Null.return (Dom_api.to_node node)
          | Nodes -> after) [@u])
    ~release:
      (fun [@u] () ->
        instance.output.release () [@u];
        instance.status <- Unmounted;
        List.iter (fun cleanup -> cleanup ()) (List.rev instance.teardown))

let render instance =
  instance.status <- Clean;
  match instance.kind with
  | Renders definition ->
      Hook.rewind instance.slots;
      within rendering (Some instance) definition.render
  | Provides provision -> provision.children

let commit (position : Template.position) instance =
  (match (Js.Null.toOption (instance.output.front Js.null [@u]), instance.region) with
  | Some _, Nodes | None, Marker _ -> ()
  | Some _, Marker node ->
      Dom_api.remove_child position.parent node;
      instance.region <- Nodes
  | None, Nodes ->
      let node = Dom_api.create_text_node Dom_api.document "" in
      View.insert position (Dom_api.to_node node);
      instance.region <- Marker node);
  List.iter
    (fun (timing, phase, job) ->
      match (timing, phase) with
      | Layout, Cleanup -> layout_cleanups := (instance, job) :: !layout_cleanups
      | Layout, Run -> layout_runs := (instance, job) :: !layout_runs
      | Passive, Cleanup -> passive_cleanups := (instance, job) :: !passive_cleanups
      | Passive, Run -> passive_runs := (instance, job) :: !passive_runs)
    (List.rev instance.pending);
  instance.pending <- []

let refresh (position : Template.position) instance =
  let child = render instance in
  let at =
    match instance.region with
    | Marker node -> { position with before = Js.Null.return (Dom_api.to_node node) }
    | Nodes -> position
  in
  instance.output <- within owner (Some instance) (fun () -> View.update at instance.output child);
  commit position instance

let settle () =
  let position_of instance =
    let live = instance_live instance in
    let last = ref None in
    live.each (fun [@u] node -> last := Some node) [@u];
    match (Option.bind (Js.Null.toOption (live.front Js.null [@u])) Dom_api.parent_node, !last) with
    | Some parent, Some last ->
        { Template.parent; before = Js.Null.fromOption (Dom_api.next_sibling last) }
    | None, _ | _, None -> Js.Exn.raiseError "melact: a mounted component is not in the DOM"
  in
  let rec drain () =
    match !dirty with
    | [] -> ()
    | pending ->
        dirty := [];
        List.iter
          (fun instance ->
            match instance.status with
            | Dirty -> refresh (position_of instance) instance
            | Clean | Unmounted -> ())
          (List.stable_sort
             (fun a b ->
               match
                 ( Js.Null.toOption ((instance_live a).front Js.null [@u]),
                   Js.Null.toOption ((instance_live b).front Js.null [@u]) )
               with
               | Some first, Some second when not (Dom_api.same first second) ->
                   if Dom_api.compare_document_position first second land 4 <> 0 then -1 else 1
               | Some _, Some _ | None, _ | _, None -> Int.compare a.depth b.depth)
             pending);
        run_phases layout_cleanups layout_runs;
        drain ()
  in
  run_phases layout_cleanups layout_runs;
  drain ();
  match (!passive_cleanups, !passive_runs, !passive_schedule) with
  | [], [], _ | _, _, Queued -> ()
  | _ :: _, _, Idle | _, _ :: _, Idle ->
      passive_schedule := Queued;
      Dom_api.request_animation_frame (fun _ -> Dom_api.set_timeout run_passive 0)

let flush () =
  render_schedule := Idle;
  settle ();
  run_passive ()

let mount_instance position kind =
  let instance =
    {
      parent = !owner;
      depth = Option.fold ~none:0 ~some:(fun parent -> parent.depth + 1) !owner;
      slots = Hook.slots ();
      kind;
      status = Clean;
      output = View.nothing;
      region = Nodes;
      pending = [];
      teardown = [];
    }
  in
  let child = render instance in
  instance.output <- within owner (Some instance) (fun () -> View.build child position);
  commit position instance;
  instance_live instance

let component definition inputs render =
  View.host
    ~build:(fun [@u] position -> mount_instance position (Renders { component = definition; inputs; render }))
    ~patch:
      (fun [@u] position live ->
        match View.hosted live with
        | Some (Instance instance) -> (
            match instance.kind with
            | Renders rendered when Dom_api.same rendered.component definition ->
                (match (instance.status, View.compare_inputs rendered.inputs inputs) with
                | Clean, View.Unchanged -> ()
                | (Clean | Dirty | Unmounted), _ ->
                    rendered.inputs <- inputs;
                    rendered.render <- render;
                    refresh position instance);
                Some live
            | Renders _ | Provides _ -> None)
        | Some _ | None -> None)

let provide : type value. value Context.t -> value -> View.child -> View.child =
 fun context value children ->
  View.host
    ~build:(fun [@u] position ->
      mount_instance position (Provides { context; value; children; consumers = [] }))
    ~patch:
      (fun [@u] position live ->
        match View.hosted live with
        | Some (Instance instance) -> (
            match instance.kind with
            | Provides provision -> (
                match Type.Id.provably_equal provision.context.witness context.witness with
                | Some Equal ->
                    if not (Dom_api.same provision.value value) then (
                      provision.value <- value;
                      List.iter mark_dirty provision.consumers;
                      provision.consumers <- []);
                    provision.children <- children;
                    refresh position instance;
                    Some live
                | None -> None)
            | Renders _ -> None)
        | Some _ | None -> None)

let current () =
  match !rendering with
  | Some instance -> instance
  | None -> Js.Exn.raiseError "melact: hooks can only be called while a component renders"

let slot instance key init = Hook.take instance.slots key init

let invalidate instance =
  match !rendering with
  | Some _ ->
      Js.Exn.raiseError "melact: a state setter was called while a component was rendering"
  | None -> (
      mark_dirty instance;
      match !render_schedule with
      | Queued -> ()
      | Idle ->
          render_schedule := Queued;
          Dom_api.queue_microtask (fun () ->
              render_schedule := Idle;
              settle ()))

let after_commit instance timing phase job =
  instance.pending <- (timing, phase, job) :: instance.pending

let on_unmount instance cleanup = instance.teardown <- cleanup :: instance.teardown

let consume : type value. instance -> value Context.t -> value =
 fun instance context ->
  let rec find ancestor =
    match ancestor with
    | None -> context.default
    | Some above -> (
        match above.kind with
        | Provides provision -> (
            match Type.Id.provably_equal provision.context.witness context.witness with
            | Some Equal ->
                if not (List.memq instance provision.consumers) then
                  provision.consumers <- instance :: provision.consumers;
                provision.value
            | None -> find above.parent)
        | Renders _ -> find above.parent)
  in
  find instance.parent
