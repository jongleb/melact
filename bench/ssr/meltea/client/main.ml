external document : Dom.document = "document"

external element_by_id : Dom.document -> string -> Dom.element option = "getElementById"
[@@mel.send] [@@mel.return nullable]

external parse : string -> Page.row array = "parse" [@@mel.scope "JSON"]
external mark : string -> unit = "mark" [@@mel.scope "performance"]
external window : < __hydrated : bool [@mel.set] > Js.t = "window"

let () =
  mark "hydrate:start";
  Option.iter
    (fun root ->
      ignore
        (Program.sandbox ~start:Program.hydrate
           ~init:
             {
               Page.count = 0;
               selection = Page.Unselected;
               rows = Option.fold ~none:[] ~some:(fun data -> Array.to_list (parse data)) (Melhole.Served.data ~id:"model");
             }
           ~update:Page.update ~view:Page.view root);
      mark "hydrate:end";
      window##__hydrated #= true)
    (element_by_id document "main")
