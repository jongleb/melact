open Melhole

(** When an effect runs after its instance is patched. *)
type timing =
  | Layout  (** Synchronously, before the browser paints. *)
  | Passive  (** After the whole flush, once the browser has painted. *)

(** Within one commit every cleanup runs before any effect, as in React. *)
type phase = Cleanup | Run

(** Whatever a component threw. *)
type caught

external caught_of : 'a -> caught = "%identity"

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
  | Catches of catching

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

and status = Clean | Dirty | Unmounted

(** Where an instance sits in the DOM when its output has no nodes. *)
and region =
  | Nodes  (** The output's own nodes locate it. *)
  | Marker of Dom.text  (** An empty text node holds its place. *)

type View.hosted += Instance of instance

(** When an error is thrown, which decides what a boundary keeps of several, as in React. *)
type stage =
  | While_rendering  (** The one thrown later in the tree wins. *)
  | In_effect  (** The one thrown last wins. *)

(** Whether an error boundary still has a step to take in this flush. *)
type outstanding = Quiet | Busy

(** What error boundaries add to a flush: nothing until the first boundary mounts. *)
type recovery = {
  rescue : (stage -> instance -> exn -> unit[@u]);  (** Hands an error to the nearest boundary that can take it. *)
  before_rendering : (unit -> unit[@u]);  (** Boundaries hit by effects drop their children, fallen ones show fallbacks. *)
  after_rendering : (unit -> unit[@u]);  (** Boundaries that caught while rendering drop their children and fail. *)
  outstanding : (unit -> outstanding[@u]);
}

(** Whether a flush is already queued. *)
type schedule = Idle | Queued

let thrown error =
  match error with
  | Js.Exn.Error raw -> ([%mel.raw "function (error) { throw error }"] : Js.Exn.t -> unit) raw
  | other -> raise other

let rendering = ref None
let recovery =
  ref
    {
      rescue = (fun [@u] _ _ error -> thrown error);
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
        match instance.status with
        | Unmounted -> ()
        | Clean | Dirty -> ( try job () with error -> !recovery.rescue In_effect instance error [@u]))
      (List.rev jobs)
  in
  let pending_cleanups = !cleanups and pending_runs = !runs in
  cleanups := [];
  runs := [];
  run_jobs pending_cleanups;
  run_jobs pending_runs

let render instance =
  instance.status <- Clean;
  match instance.kind with
  | Renders definition ->
      Hook.rewind instance.slots;
      within rendering (Some instance) definition.render
  | Provides provision -> provision.children
  | Catches catching -> (
      match catching.failure with
      | Healthy | Caught _ | Struck _ -> catching.children
      | Failed error -> catching.recover error)

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
  match render instance with
  | child ->
      let at =
        match instance.region with
        | Marker node -> { position with before = Js.Null.return (Dom_api.to_node node) }
        | Nodes -> position
      in
      instance.output <- within owner (Some instance) (fun () -> View.update at instance.output child);
      commit position instance
  | exception error ->
      instance.pending <- [];
      !recovery.rescue While_rendering instance error [@u]

let rec settle () =
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
    match (!dirty, !layout_cleanups, !layout_runs, !recovery.outstanding () [@u]) with
    | [], [], [], Quiet -> ()
    | _ ->
        !recovery.before_rendering () [@u];
        let pending = !dirty in
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
        !recovery.after_rendering () [@u];
        run_phases layout_cleanups layout_runs;
        (match !recovery.outstanding () [@u] with Quiet -> () | Busy -> run_phases passive_cleanups passive_runs);
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
  match !recovery.outstanding () [@u] with Quiet -> () | Busy -> settle ()

let flush () =
  render_schedule := Idle;
  settle ();
  run_passive ()

let born kind =
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
  instance

let mount_instance position kind =
  let instance = born kind in
  (match render instance with
  | child ->
      instance.output <- within owner (Some instance) (fun () -> View.build child position);
      commit position instance
  | exception error ->
      instance.pending <- [];
      commit position instance;
      !recovery.rescue While_rendering instance error [@u]);
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
            | Renders _ | Provides _ | Catches _ -> None)
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
            | Renders _ | Catches _ -> None)
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
        | Renders _ | Catches _ -> find above.parent)
  in
  find instance.parent

let catch =
  let caught_boundaries = ref [] and struck_boundaries = ref [] and fallen_boundaries = ref [] in
  let record stage instance error =
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
                | Renders _ | Provides _ -> Js.Null.toOption ((instance_live instance).front Js.null [@u])
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
    boundary.output.release () [@u];
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
              | { status = Clean | Dirty; kind = Catches ({ failure = Struck error; _ } as catching); _ } ->
                  blank boundary catching;
                  catching.failure <- Caught { error; thrower = boundary };
                  caught_boundaries := boundary :: !caught_boundaries
              | _ -> ())
            (taken struck_boundaries);
          List.iter
            (fun boundary ->
              match boundary with
              | { status = Clean | Dirty; kind = Catches ({ failure = Failed _; _ } as catching); _ } -> (
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
              | { status = Clean | Dirty; kind = Catches ({ failure = Caught { error; _ }; _ } as catching); _ } ->
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
            boundary.output.each (fun [@u] node -> last := node) [@u];
            Dom_api.insert_before position.parent (Dom_api.to_node finish) (Dom_api.following_sibling !last));
        View.live (Instance boundary)
          ~each:(fun [@u] visit ->
            visit (Dom_api.to_node start) [@u];
            boundary.output.each visit [@u];
            visit (Dom_api.to_node finish) [@u])
          ~front:(fun [@u] _ -> Js.Null.return (Dom_api.to_node start))
          ~release:(fun [@u] () ->
            boundary.output.release () [@u];
            boundary.status <- Unmounted))
      ~patch:(fun [@u] _ live ->
        match View.hosted live with
        | Some (Instance ({ kind = Catches catching; _ } as boundary)) ->
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
