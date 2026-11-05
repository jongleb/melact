(** reason-react's [ReactDOMServer] for melact: a view as HTML, to send from a server and hydrate. *)

val renderToString : React.element -> string
val renderToStaticMarkup : React.element -> string
