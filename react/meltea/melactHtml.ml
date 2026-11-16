open Melhole

external queue_microtask : (unit -> unit) -> unit = "queueMicrotask"

(** Whether a settle of Melact's instances waits for the end of the draw under way. *)
type settling = Idle | Queued

let settling = ref Idle

let melact =
  Meltea_runtime.View.hosting
    ~visit:(fun [@u] live see -> View.visit live see)
    ~first:(fun [@u] live after -> View.front live after)
    ~let_go:(fun [@u] live -> View.release live)

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
      Meltea_runtime.View.host
        ~build:(fun [@u] position ->
          drawn ();
          Meltea_runtime.View.live melact (View.build child position))
        ~patch:(fun [@u] position live ->
          drawn ();
          Option.map
            (fun inner -> Meltea_runtime.View.live melact (View.update position inner child))
            (Meltea_runtime.View.hosted melact live)))
