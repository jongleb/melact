external document : Dom.document = "document"

external element_by_id : Dom.document -> string -> Dom.element option = "getElementById"
[@@mel.send] [@@mel.return nullable]

external parse : string -> (int * string * Page.status) array = "parse" [@@mel.scope "JSON"]
external search : string = "search" [@@mel.scope "location"]
external mark : string -> unit = "mark" [@@mel.scope "performance"]
external measure : string -> string -> unit = "measure" [@@mel.scope "performance"]

let () =
  Option.iter
    (fun root ->
      let todos =
        Array.to_list
          (Array.map
             (fun (id, title, status) -> { Page.id; title; status })
             (parse (Option.value ~default:"[]" (Melhole.Served.data ~id:"model"))))
      in
      mark "start";
      ignore
        (Program.sandbox
           ~start:(match search with "?resume" -> Program.resume | _ -> Program.hydrate)
           ~init:{ Page.todos; field = ""; editing = Not_editing; filter = All; next = List.length todos }
           ~update:Page.update
           ~view:(fun model ->
             mark "view";
             Page.view model)
           root);
      measure "start" "start")
    (element_by_id document "root")
