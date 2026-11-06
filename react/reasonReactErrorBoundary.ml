open Melact_runtime

type info = { componentStack : string }
type 'error params = { error : 'error; info : info }

external unchecked : Instance.caught -> 'error = "%identity"

external makeProps :
  children:React.element ->
  fallback:('error params -> React.element) ->
  ?key:string ->
  unit ->
  < children : React.element ; fallback : 'error params -> React.element > Js.t = ""
[@@mel.obj]

let make props =
  let fallback = props##fallback in
  React.of_child
    (Instance.catch
       ~recover:(fun caught -> React.to_child (fallback { error = unchecked caught; info = { componentStack = "" } }))
       (React.to_child props##children))
