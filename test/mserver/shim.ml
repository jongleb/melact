let theme = React.createContext "light"

module Theme = struct
  let make = React.Context.provider theme

  external makeProps : value:string -> children:React.element -> unit -> < value : string ; children : React.element > Js.t
    = ""
  [@@mel.obj]
end

let html text = [%mel.obj { __html = text }]
