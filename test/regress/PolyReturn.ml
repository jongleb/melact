let make ~busy ~onClose =
  let close _ : unit = if busy then () else onClose () in
  React.useEffect1 (fun () -> None) [| busy |];
  ((PolyLet.Modal.createElement ~onClose:close ~children:[ ((PolyLet.Button.createElement ~onClick:close ~children:[] ()) [@JSX]) ] ()) [@JSX])
[@@react.component]
