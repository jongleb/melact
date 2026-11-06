let theme = React.createContext "light"

module Theme = struct
  let make props = React.Context.provider theme props
  let makeProps ~value ~children () = React.Context.makeProps ~value ~children ()
end

let html text =
  object
    method __html = text
  end
