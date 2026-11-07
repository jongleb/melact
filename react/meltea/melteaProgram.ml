open Melhole
open Melact_runtime

(** What a program is made of, with its two ends towards the component around it. *)
type ('input, 'report, 'model, 'msg) spec = {
  init : 'input -> 'model * 'msg Cmd.t;
  update : 'msg -> 'model -> 'model * 'msg Cmd.t;
  view : 'model -> 'msg Html.t;
  subscriptions : 'model -> 'msg Sub.t;
  receive : 'input -> 'msg option;
  report : 'msg -> 'model -> 'report option;
}

(** Whether a mounted program still takes messages. *)
type life = Live | Stopped

(** The model a program's view was last drawn for, if any. *)
type 'model drawn = Undrawn | Drawn of 'model

(** A program mounted in one instance. *)
type ('input, 'report, 'model, 'msg) running = {
  mutable model : 'model;
  mutable input : 'input;  (** The input the model last took in. *)
  mutable drawn : 'model drawn;
  mutable life : life;
  mutable listener : 'report -> unit;  (** The [onReport] of the last render. *)
  mutable waiting : 'msg Cmd.t list;  (** Commands to run once the instance is committed, newest first. *)
  active : 'msg Sub.active;
  send : 'msg -> unit;
}

type ('input, 'report) t =
  | Program : {
      component : Component.t;
      slot : ('input, 'report, 'model, 'msg) running Hook.key;
      spec : ('input, 'report, 'model, 'msg) spec;
    }
      -> ('input, 'report) t

let element ?(receive = fun _ -> None) ?(report = fun _ _ -> None) ~init ~update ~view ~subscriptions name =
  Program { component = Component.pure ~name; slot = Hook.key (); spec = { init; update; view; subscriptions; receive; report } }

let sandbox ?receive ?report ~init ~update ~view name =
  element ?receive ?report
    ~init:(fun input -> (init input, Cmd.none))
    ~update:(fun message model -> (update message model, Cmd.none))
    ~view
    ~subscriptions:(fun _ -> Sub.none)
    name

type make_props = Make_props of React.element [@@unboxed]

external make : make_props -> React.element = "%identity"

let makeProps ~program ~input ?(onReport = ignore) ?key () =
  match program with
  | Program { component; slot; spec } ->
      let render () =
        let instance = Instance.current () in
        let running =
          Instance.slot instance slot (fun () ->
              let model, commands = spec.init input in
              let active = Sub.activate () in
              let rec running =
                {
                  model;
                  input;
                  drawn = Undrawn;
                  life = Live;
                  listener = onReport;
                  waiting = [ commands ];
                  active;
                  send =
                    (fun message ->
                      match running.life with
                      | Stopped -> ()
                      | Live -> (
                          let before = running.model in
                          let model, commands = spec.update message before in
                          running.model <- model;
                          Option.iter running.listener (spec.report message model);
                          Cmd.run commands running.send;
                          Cmd.drawing := Cmd.Instant;
                          match View.check (View.Input before) model with
                          | View.Changed -> Instance.invalidate instance
                          | View.Unchanged -> ()));
                }
              in
              Instance.on_unmount instance (fun () ->
                  running.life <- Stopped;
                  Sub.apply running.active Sub.none ignore);
              running)
        in
        running.listener <- onReport;
        (match View.check (View.Input running.input) input with
        | View.Unchanged -> ()
        | View.Changed ->
            running.input <- input;
            Option.iter
              (fun message ->
                let model, commands = spec.update message running.model in
                running.model <- model;
                running.waiting <- commands :: running.waiting)
              (spec.receive input));
        let change =
          match running.drawn with
          | Undrawn -> View.Changed
          | Drawn model -> View.check (View.Input model) running.model
        in
        (match (change, running.waiting) with
        | View.Unchanged, [] -> ()
        | (View.Changed | View.Unchanged), _ ->
            Instance.after_commit instance Instance.Layout Instance.Run (fun () ->
                let commands = List.rev running.waiting in
                running.waiting <- [];
                (match change with
                | View.Changed -> Sub.apply running.active (spec.subscriptions running.model) running.send
                | View.Unchanged -> ());
                List.iter (fun command -> Cmd.run command running.send) commands;
                Cmd.drawing := Cmd.Instant));
        match change with
        | View.Unchanged -> Instance.unchanged
        | View.Changed ->
            running.drawn <- Drawn running.model;
            Html.render (spec.view running.model) running.send
      in
      let mounted = Instance.component component [| View.Input input; View.Input onReport |] render in
      Make_props (React.of_child (Option.fold ~none:mounted ~some:(fun key -> View.with_key key mounted) key))
