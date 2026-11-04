open Melhole

external queue_microtask : (unit -> unit) -> unit = "queueMicrotask"

type 'msg t = { send : 'msg -> unit; draw : unit -> unit; halt : unit -> unit }

(** Whether a redraw is waiting for the next microtask. *)
type schedule = Idle | Queued

let element ~init ~update ~view ~subscriptions root =
  let initial, commands = init in
  let model = ref initial and schedule = ref Idle and sink = ref ignore in
  let dispatch message = !sink message in
  let active = Sub.activate () in
  let mounted =
    let (Html.Node render) = view initial in
    View.mount (render dispatch) ~parent:root ~before:None
  in
  let draw () =
    match !schedule with
    | Idle -> ()
    | Queued ->
        schedule := Idle;
        let (Html.Node render) = view !model in
        View.patch mounted (render dispatch);
        Sub.apply active (subscriptions !model) dispatch
  in
  sink :=
    (fun message ->
      let next, commands = update message !model in
      model := next;
      Cmd.run commands dispatch;
      match !schedule with
      | Queued -> ()
      | Idle ->
          schedule := Queued;
          queue_microtask draw);
  Sub.apply active (subscriptions initial) dispatch;
  Cmd.run commands dispatch;
  {
    send = dispatch;
    draw;
    halt =
      (fun () ->
        Sub.apply active Sub.none dispatch;
        View.unmount mounted);
  }

let sandbox ~init ~update ~view root =
  element ~init:(init, Cmd.none)
    ~update:(fun message model -> (update message model, Cmd.none))
    ~view
    ~subscriptions:(fun _ -> Sub.none)
    root

let dispatch program message = program.send message
let flush program = program.draw ()
let stop program = program.halt ()
