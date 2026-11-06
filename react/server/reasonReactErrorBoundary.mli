(** reason-react's error boundary in Melact's server build: as on React's server, it writes its
    children, and an error goes on to the nearest Suspense boundary, or out of [renderToString]. *)

(** Where the error happened. *)
type info = { componentStack : string }

(** What [fallback] would receive on the client. *)
type 'error params = { error : 'error; info : info }

external makeProps :
  children:React.element ->
  fallback:('error params -> React.element) ->
  ?key:string ->
  unit ->
  < children : React.element ; fallback : 'error params -> React.element > Js.t = ""
[@@mel.obj]

val make : < children : React.element ; fallback : 'error params -> React.element > Js.t React.component
