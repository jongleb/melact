type ('element, 'position) hole =
  | Attr of 'element * string
  | Prop of 'element * string
  | Text of 'position
  | Child of 'position
  | Handler of 'element * string
  | Ref of 'element
  | Style of 'element
  | Class_list of 'element

type position = { parent : Dom.node; before : Dom.node option }

type t = {
  html : string;
  holes : (int list, int list * int) hole array;
  root : Dom.element Lazy.t;
}

let element_of node =
  match Dom_api.node_type node with
  | 1 -> Some (Dom_api.unsafe_element node)
  | _ -> None

let make ~html ~holes =
  let root =
    lazy
      (let template = Dom_api.create_element Dom_api.document "template" in
       Dom_api.set_inner_html template html;
       match
         Option.bind
           (Dom_api.first_child (Dom_api.template_content template))
           element_of
       with
       | Some root -> root
       | None -> Js.Exn.raiseError ("Melact template needs a root element: " ^ html))
  in
  { html; holes; root }

let clone t =
  let root = Dom_api.clone_node (Lazy.force t.root) in
  let fail path =
    Js.Exn.raiseError
      (Printf.sprintf "Melact template path [%s] does not resolve in %s"
         (String.concat "; " (List.map string_of_int path))
         t.html)
  in
  let rec slot candidate index =
    match (candidate, index) with
    | _, 0 -> Ok candidate
    | Some node, _ -> slot (Dom_api.next_sibling node) (index - 1)
    | None, _ -> Error ()
  in
  let rec descend element path =
    match path with
    | [] -> Some element
    | index :: rest -> (
        match slot (Dom_api.first_child element) index with
        | Ok (Some node) ->
            Option.bind (element_of node) (fun child -> descend child rest)
        | Ok None | Error () -> None)
  in
  let element path =
    match descend root path with Some element -> element | None -> fail path
  in
  let position (path, index) =
    let parent = element path in
    match slot (Dom_api.first_child parent) index with
    | Ok before -> { parent = Dom_api.to_node parent; before }
    | Error () -> fail (path @ [ index ])
  in
  ( root,
    Array.map
      (fun hole ->
        match hole with
        | Attr (path, name) -> Attr (element path, name)
        | Prop (path, name) -> Prop (element path, name)
        | Text at -> Text (position at)
        | Child at -> Child (position at)
        | Handler (path, name) -> Handler (element path, name)
        | Ref path -> Ref (element path)
        | Style path -> Style (element path)
        | Class_list path -> Class_list (element path))
      t.holes )
