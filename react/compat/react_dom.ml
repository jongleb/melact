open Melact_runtime

let createPortal children container key =
  Raw.record
    [
      ("$$typeof", Element.Mark.portal);
      ("key", Option.fold ~none:Raw.null ~some:(fun key -> Raw.of_any (Raw.text_of key)) (Raw.present key));
      ("children", children);
      ("containerInfo", container);
      ("implementation", Raw.null);
    ]

let flushSync run =
  let result = Option.fold ~none:Raw.undefined ~some:Raw.call0 (Raw.present run) in
  (match Instance.writing_component () with Some _ -> () | None -> Instance.flush ());
  result

let createRoot container _ =
  let root = ReactDOMClient.createRoot container in
  Raw.record
    [
      ("render", Raw.of_any (fun element -> ReactDOMClient.render root (React.of_child (Render.child element))));
      ("unmount", Raw.of_any (fun () -> ReactDOMClient.unmount root ()));
    ]

let roots : Raw.t Raw.table = Raw.table ()

let render element container callback =
  let root =
    match Raw.lookup roots (Raw.of_any container) with
    | Some root -> root
    | None ->
        let made = createRoot container Raw.undefined in
        Raw.store roots (Raw.of_any container) made;
        made
  in
  ignore (Raw.call1 (Raw.get root "render") element);
  Option.iter (fun callback -> ignore (Raw.call0 callback)) (Raw.present callback)

let unmountComponentAtNode container =
  match Raw.lookup roots (Raw.of_any container) with
  | Some root ->
      ignore (Raw.call0 (Raw.get root "unmount"));
      Raw.store roots (Raw.of_any container) Raw.undefined;
      true
  | None -> false

let findDOMNode value =
  match Raw.view value with
  | Missing -> Raw.null
  | Record record when Raw.same (Raw.get record "nodeType") Raw.undefined |> not -> record
  | _ -> Js.Exn.raiseError "melact: findDOMNode of a component is not supported; use a ref"
