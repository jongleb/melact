type info = { componentStack : string }
type 'error params = { error : 'error; info : info }
type 'error props = { children : React.element; fallback : 'error params -> React.element }

let makeProps ~children ~fallback ?key:_ () = { children; fallback }
let make props = props.children
