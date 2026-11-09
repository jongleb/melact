open Melhole

(** What a root shows. *)
type content =
  | Nothing
  | Showing of View.mounted
  | Resuming of { taken : unit -> View.mounted; left : unit -> unit }  (** A server's page, taken over at its first input. *)

type root = { container : Dom.element; mutable content : content }

let createRoot container = { container; content = Nothing }

let render root element =
  let child = React.to_child element in
  (match root.content with
  | Showing mounted -> View.patch mounted child
  | Resuming { taken; _ } ->
      let mounted = taken () in
      root.content <- Showing mounted;
      View.patch mounted child
  | Nothing -> root.content <- Showing (View.mount child ~parent:root.container ~before:None));
  Melact_runtime.Instance.settle_in_event ()

let hydrateRoot container element =
  let root = createRoot container in
  Melact_runtime.Instance.number_from_root ();
  root.content <- Showing (Served.hydrate (React.to_child element) ~parent:container);
  Melact_runtime.Instance.settle ();
  root

let resumeRoot container element =
  let root = createRoot container in
  let page =
    Served.resumable
      (fun () ->
        Melact_runtime.Instance.number_from_root ();
        React.to_child element)
      ~taken:Melact_runtime.Instance.flush ~parent:container
  in
  root.content <- Resuming { taken = (fun () -> Served.resumed page); left = (fun () -> Served.leave page) };
  root

let unmount root () =
  match root.content with
  | Showing mounted ->
      View.unmount mounted;
      root.content <- Nothing
  | Resuming { left; _ } ->
      left ();
      root.content <- Nothing
  | Nothing -> ()
