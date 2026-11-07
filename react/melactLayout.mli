(** Layout helpers of Melact's own, not React's. *)

(** A long list cut into groups of [size] rows (default 100), each a [tag] element (default
    ["div"]) with [content-visibility: auto] and a height estimate from [rowHeight] pixels
    (default 40): the browser skips style, layout and paint of the groups out of view. Give it the
    keyed rows, as [React.array] of elements with keys. The groups change the DOM, so selectors
    such as [:nth-child] see them; a row that moves to another group is mounted again there and
    loses its state. *)
val chunked : ?size:int -> ?rowHeight:int -> ?tag:string -> React.element -> React.element
