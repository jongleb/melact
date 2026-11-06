open Melhole

(** What a root shows. *)
type content =
  | Nothing
  | Showing of View.mounted
  | Resuming of Served.resumable  (** A server's page, taken over at its first input. *)

type root = { container : Dom.element; mutable content : content }

let createRoot container = { container; content = Nothing }

let render root element =
  let child = React.to_child element in
  (match root.content with
  | Showing mounted -> View.patch mounted child
  | Resuming page ->
      let mounted = Served.resumed page in
      root.content <- Showing mounted;
      View.patch mounted child
  | Nothing -> root.content <- Showing (View.mount child ~parent:root.container ~before:None));
  Melact_runtime.Instance.settle ()

let hydrateRoot container element =
  let root = createRoot container in
  Melact_runtime.Instance.number_from_root ();
  root.content <- Showing (Served.hydrate (React.to_child element) ~parent:container);
  Melact_runtime.Instance.settle ();
  root

let resumeRoot container element =
  let root = createRoot container in
  root.content <-
    Resuming
      (Served.resumable
         (fun () ->
           Melact_runtime.Instance.number_from_root ();
           React.to_child element)
         ~taken:Melact_runtime.Instance.flush ~parent:container);
  root

let unmount root () =
  match root.content with
  | Showing mounted ->
      View.unmount mounted;
      root.content <- Nothing
  | Resuming page ->
      Served.leave page;
      root.content <- Nothing
  | Nothing -> ()
