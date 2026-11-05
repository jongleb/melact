open Melact_runtime

type info = { componentStack : string }
type 'error params = { error : 'error; info : info }

external unchecked : Instance.caught -> 'error = "%identity"

let make ~children ~fallback () =
  React.of_child
    (Instance.catch
       ~recover:(fun caught -> React.to_child (fallback { error = unchecked caught; info = { componentStack = "" } }))
       (React.to_child children))

let makeProps ~children ~fallback ?key () make =
  Option.fold ~none:(make ~children ~fallback ())
    ~some:(fun key -> React.of_child (Melhole.View.with_key key (React.to_child (make ~children ~fallback ()))))
    key
