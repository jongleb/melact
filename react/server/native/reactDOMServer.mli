(** reason-react's [ReactDOMServer] for Melact's native server build: an element as HTML, written without a
    DOM, as React 18's [renderToString] and [renderToStaticMarkup] write it. *)

val renderToString : React.element -> string
val renderToStaticMarkup : React.element -> string
