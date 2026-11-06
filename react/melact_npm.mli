(** What melact-ppx turns bindings to npm React's element functions into: [createElement] from
    ["react"], [jsx], [jsxs] and [jsxDEV] from ["react/jsx-runtime"], and [Fragment]. A string tag
    builds a DOM element from its props object; a component is called with its props, with the
    children put in them as React does. Only bindings that return [React.element] are rewritten: one
    that returns a type of its own means npm React's elements on purpose. *)

val created : 'kind -> 'props -> React.element array -> React.element
val keyed : React.element -> string option -> React.element
val fragment : < children : React.element > Js.t -> React.element
