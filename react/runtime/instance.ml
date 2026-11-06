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

and status = Clean | Dirty | Unmounted

(** Where an instance sits in the DOM when its output has no nodes. *)
and region =
  | Nodes  (** The output's own nodes locate it. *)
  | Marker of Dom.text  (** An empty text node holds its place. *)

type View.hosted += Instance of instance

(** What [use] throws for a promise that has not settled: the nearest Suspense boundary catches it. *)
exception Suspended of thenable

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
        | Clean | Dirty -> ( try job () with error -> !suspension.rescue In_effect instance error [@u]))
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
  | Suspends suspending -> suspending.wanted
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
  let at =
    match instance.region with
    | Marker node -> { position with before = Js.Null.return (Dom_api.to_node node) }
    | Nodes -> position
  in
  match
    let child = render instance in
    within owner (Some instance) (fun () -> View.update at instance.output child)
  with
  | output ->
      instance.output <- output;
      commit position instance
  | exception error ->
      instance.pending <- [];
      !suspension.rescue While_rendering instance error [@u]

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
    match (!dirty, !layout_cleanups, !layout_runs, !recovery.outstanding () [@u], !suspension.outstanding () [@u]) with
    | [], [], [], Quiet, Quiet -> ()
    | _ ->
        !recovery.before_rendering () [@u];
        !suspension.before_rendering () [@u];
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
        !suspension.after_rendering () [@u];
        run_phases layout_cleanups layout_runs;
        (match (!recovery.outstanding () [@u], !suspension.outstanding () [@u]) with
        | Quiet, Quiet -> ()
        | Busy, _ | _, Busy -> run_phases passive_cleanups passive_runs);
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
  (match
     let child = render instance in
     within owner (Some instance) (fun () -> View.build child position)
   with
  | output ->
      instance.output <- output;
      commit position instance
  | exception error ->
      instance.pending <- [];
      commit position instance;
      !suspension.rescue While_rendering instance error [@u]);
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
            | Renders _ | Provides _ | Catches _ | Suspends _ -> None)
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
            | Renders _ | Catches _ | Suspends _ -> None)
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
        | Renders _ | Catches _ | Suspends _ -> find above.parent)
  in
  find instance.parent

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

let suspend =
  let suspended = ref [] and retried = ref [] and fresh = ref [] in
  let queued () =
    match !render_schedule with
    | Queued -> ()
    | Idle ->
        render_schedule := Queued;
        Dom_api.queue_microtask (fun () ->
            render_schedule := Idle;
            settle ())
  in
  let nodes (live : View.live) =
    let found = ref [] in
    live.each (fun [@u] node -> found := node :: !found) [@u];
    List.rev !found
  in
  let removed (live : View.live) =
    let gone = nodes live in
    live.release () [@u];
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
              | { status = Clean | Dirty; kind = Suspends ({ waiting = Retrying { content; throwers }; _ } as suspending); _ }
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
              | { status = Clean | Dirty; kind = Suspends ({ waiting = Suspending { promise; throwers }; _ } as suspending); _ }
                ->
                  let content =
                    match List.memq boundary built with
                    | true ->
                        suspending.content.release () [@u];
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
                        queued ()
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
  fun ~fallback children ->
    View.host
      ~build:(fun [@u] (position : Template.position) ->
        suspension := installed;
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
        | View.Server_nodes ->
            suspending.content <- within owner (Some boundary) (fun () -> View.build children position);
            let last = ref (Dom_api.to_node opening) in
            suspending.content.each (fun [@u] node -> last := node) [@u];
            Dom_api.insert_before position.parent (Dom_api.to_node closing) (Dom_api.following_sibling !last));
        View.live (Instance boundary)
          ~each:(fun [@u] visit ->
            visit (Dom_api.to_node opening) [@u];
            suspending.content.each visit [@u];
            suspending.backup.each visit [@u];
            visit (Dom_api.to_node closing) [@u])
          ~front:(fun [@u] _ -> Js.Null.return (Dom_api.to_node opening))
          ~release:(fun [@u] () ->
            suspending.content.release () [@u];
            suspending.backup.release () [@u];
            boundary.status <- Unmounted))
      ~patch:(fun [@u] _ live ->
        match View.hosted live with
        | Some (Instance ({ kind = Suspends suspending; _ } as boundary)) ->
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
