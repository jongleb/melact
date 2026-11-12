(** What melact-ppx emits for a component of a JavaScript React library when the build picks islands
    ([-foreign-engine island]): the component runs on npm's React, in an island. JSX written inside
    such a component's children, DOM tags and other bound components, compiles to npm's React
    elements, so the library can inspect and clone them; anything else stays Melact content, in a slot. *)

(** A JavaScript component, as its module exports it. *)
type foreign

(** The props object [makeProps] builds. *)
type props

(** A React element, or Melact content where a library takes its children. *)
type node

(** The component with its props, as Melact content. *)
val mount : foreign -> props -> React.element

(** The component with its props, as a React element for another bound component's children. *)
val element : foreign -> props -> node

(** A DOM tag written in a bound component's children: [host tag props children]. *)
val host : string -> (string * node) array -> node array -> node

external value : 'a -> node = "%identity"
external content : React.element -> node = "%identity"
external many : node array -> node = "%identity"

(** A React element passed where the bound component's types say [React.element]. *)
external as_element : node -> React.element = "%identity"
