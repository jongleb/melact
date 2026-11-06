(** reason-react's error boundary in Melact's native server build: as on React's server, it writes
    its children, and an error goes on to the nearest Suspense boundary, or out of [renderToString]. *)

(** Where the error happened. *)
type info = { componentStack : string }

(** What [fallback] would receive on the client. *)
type 'error params = { error : 'error; info : info }

(** The boundary's props: a record, where reason-react has a JavaScript object. *)
type 'error props = { children : React.element; fallback : 'error params -> React.element }

val makeProps :
  children:React.element -> fallback:('error params -> React.element) -> ?key:string -> unit -> 'error props

val make : 'error props React.component
