let () =
  let count = int_of_string Sys.argv.(1) in
  let model = Page.generate count in
  let json =
    "["
    ^ String.concat ","
        (List.map
           (fun (todo : Page.todo) ->
             Printf.sprintf "[%d,%S,%d]" todo.id todo.title (match todo.status with Active -> 0 | Completed -> 1))
           model.todos)
    ^ "]"
  in
  print_string
    ("<!doctype html><html><head><meta charset=\"utf-8\"><title>resume</title><link rel=\"stylesheet\" href=\"/style.css\"><script>"
   ^ Melhole_server.capture ^ "</script>"
   ^ Melhole_server.data ~id:"model" json
   ^ "</head><body><div id=\"root\">"
   ^ Program.render ~view:Page.view model
   ^ "</div><script type=\"module\" src=\"SCRIPT\"></script></body></html>")
