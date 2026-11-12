type foreign
type props
type node

external islands_foreign : foreign -> Islands.foreign = "%identity"
external islands_props : props -> Islands.props = "%identity"
external of_element : Npm.element -> node = "%identity"
external fields : < .. > Js.t -> 'props Js.t = "%identity"
external props_fields : props -> 'props Js.t = "%identity"
external of_nodes : node array -> Npm.element array = "%identity"
external value : 'a -> node = "%identity"
external content : React.element -> node = "%identity"
external many : node array -> node = "%identity"
external as_element : node -> React.element = "%identity"
external set_field : < .. > Js.t -> string -> node -> unit = "" [@@mel.set_index]

let mount foreign props = React.of_child (Islands.mount (islands_foreign foreign) (islands_props props))
let element foreign props = of_element (Npm.create_element (Npm.kind foreign) (props_fields props))

let host tag props children =
  let given = Js.Obj.empty () in
  Array.iter (fun (name, inner) -> set_field given name inner) props;
  of_element (Npm.tag_with tag (fields given) (of_nodes children))
