external document : Dom.document = "document"

external element_by_id : Dom.document -> string -> Dom.element option = "getElementById"
[@@mel.send] [@@mel.return nullable]

let () =
  Option.iter
    (fun root ->
      ignore
        (Program.sandbox
           ~init:(Page.init ~seed:(int_of_float (Js.Math.random () *. 1e9)))
           ~update:Page.update ~view:Page.view root))
    (element_by_id document "main")
