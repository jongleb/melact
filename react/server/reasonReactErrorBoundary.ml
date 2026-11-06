type info = { componentStack : string }
type 'error params = { error : 'error; info : info }

external makeProps :
  children:React.element ->
  fallback:('error params -> React.element) ->
  ?key:string ->
  unit ->
  < children : React.element ; fallback : 'error params -> React.element > Js.t = ""
[@@mel.obj]

let make props = props##children
