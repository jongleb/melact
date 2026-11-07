(** What melact-ppx emits for a component of a JavaScript React library, bound by
    [[@react.component] external make : … = "default" [@@mel.module "…"]]: the component runs on
    melact.compat. JSX written inside such a component's children, DOM tags and other bound
    components, compiles to React elements, so the library can inspect and clone them; anything else
    stays Melact content and is rendered as it is. *)

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
val many : node array -> node

(** A React element passed where the bound component's types say [React.element]. *)
external as_element : node -> React.element = "%identity"
