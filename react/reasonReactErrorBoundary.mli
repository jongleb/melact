(** reason-react's error boundary for Melact: [children] until a descendant throws while rendering,
    in a state update or in an effect, then [fallback] of what it threw. *)

(** Where the error happened; Melact keeps no component stack, so it is empty. *)
type info = { componentStack : string }

(** What [fallback] receives: whatever the descendant threw, unchecked as in reason-react. *)
type 'error params = { error : 'error; info : info }

external makeProps :
  children:React.element ->
  fallback:('error params -> React.element) ->
  ?key:string ->
  unit ->
  < children : React.element ; fallback : 'error params -> React.element > Js.t = ""
[@@mel.obj]

val make : < children : React.element ; fallback : 'error params -> React.element > Js.t React.component
