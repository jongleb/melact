open Melhole

(** What a root shows. *)
type content = Nothing | Showing of View.mounted

type root = { container : Dom.element; mutable content : content }

let createRoot container = { container; content = Nothing }

let render root element =
  let child = React.to_child element in
  (match root.content with
  | Showing mounted -> View.patch mounted child
  | Nothing -> root.content <- Showing (View.mount child ~parent:root.container ~before:None));
  Melact_runtime.Instance.settle ()

let hydrateRoot container element =
  let root = createRoot container in
  root.content <- Showing (Served.hydrate (React.to_child element) ~parent:container);
  Melact_runtime.Instance.settle ();
  root

let unmount root () =
  match root.content with
  | Showing mounted ->
      View.unmount mounted;
      root.content <- Nothing
  | Nothing -> ()
