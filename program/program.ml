external queue_microtask : (unit -> unit) -> unit = "queueMicrotask"

(** Whether a patch is already queued for the current model. *)
type schedule = Idle | Queued

let sandbox ~init ~update ~view root =
  let model = ref init and schedule = ref Idle in
  let rec dispatch message =
    model := update message !model;
    match !schedule with
    | Queued -> ()
    | Idle ->
        schedule := Queued;
        queue_microtask (fun () ->
            schedule := Idle;
            Melact_view.View.patch (Lazy.force mounted) (view dispatch !model))
  and mounted =
    lazy (Melact_view.View.mount (view dispatch init) ~parent:root ~before:None)
  in
  ignore (Lazy.force mounted)
