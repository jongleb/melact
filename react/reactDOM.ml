open Melact_view

module Client = struct
  (** What a root shows. *)
  type content = Nothing | Showing of View.mounted

  type root = { container : Dom.element; mutable content : content }

  let createRoot container = { container; content = Nothing }

  let render root (React.Element child) =
    match root.content with
    | Showing mounted -> View.patch mounted child
    | Nothing ->
        root.content <- Showing (View.mount child ~parent:root.container ~before:None)

  let unmount root () =
    match root.content with
    | Showing mounted ->
        View.unmount mounted;
        root.content <- Nothing
    | Nothing -> ()
end

let roots = ref []

let render element container =
  let root =
    match List.find_opt (fun (known, _) -> known == container) !roots with
    | Some (_, root) -> root
    | None ->
        let root = Client.createRoot container in
        roots := (container, root) :: !roots;
        root
  in
  Client.render root element

let flushSync run =
  run ();
  View.flush ()
