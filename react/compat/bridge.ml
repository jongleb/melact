type foreign
type props
type node

let element foreign props : node = Raw.to_any (Element.create (Raw.of_any foreign) (Raw.of_any props) [||])
let mount foreign props = React.of_child (Render.child (Raw.of_any (element foreign props)))

let host tag props children : node =
  let config = Raw.record (Array.to_list (Array.map (fun (name, value) -> (name, Raw.of_any value)) props)) in
  Raw.to_any (Element.create (Raw.of_any tag) config (Array.map Raw.of_any children))

external value : 'a -> node = "%identity"
external content : React.element -> node = "%identity"
external many : node array -> node = "%identity"
external as_element : node -> React.element = "%identity"
