open Melhole

external queue_microtask : (unit -> unit) -> unit = "queueMicrotask"

(** Whether a settle of Melact's instances waits for the end of the draw under way. *)
type settling = Idle | Queued

let settling = ref Idle

let element make =
  Html.node (fun send ->
      let child = React.to_child (make send) in
      let drawn () =
        match !settling with
        | Queued -> ()
        | Idle ->
            settling := Queued;
            queue_microtask (fun () ->
                settling := Idle;
                Melact_runtime.Instance.settle ())
      in
      View.host
        ~build:(fun [@u] position ->
          drawn ();
          View.build child position)
        ~patch:(fun [@u] position live ->
          drawn ();
          Some (View.update position live child)))
