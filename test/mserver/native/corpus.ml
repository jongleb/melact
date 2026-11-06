let json text =
  let buffer = Buffer.create (String.length text + 2) in
  Buffer.add_char buffer '"';
  String.iter
    (fun character ->
      match character with
      | '"' -> Buffer.add_string buffer "\\\""
      | '\\' -> Buffer.add_string buffer "\\\\"
      | '\n' -> Buffer.add_string buffer "\\n"
      | character when Char.code character < 0x20 -> Buffer.add_string buffer (Printf.sprintf "\\u%04x" (Char.code character))
      | character -> Buffer.add_char buffer character)
    text;
  Buffer.add_char buffer '"';
  Buffer.contents buffer

let () =
  let state = Random.State.make [| 20261106 |] in
  let pages =
    List.init 400 (fun _ ->
        let tape = Array.init (Random.State.int state 200) (fun _ -> Random.State.int state 1000) in
        Printf.sprintf "{\"tape\":[%s],\"html\":%s,\"markup\":%s}"
          (String.concat "," (Array.to_list (Array.map string_of_int tape)))
          (json (Rendered.page tape)) (json (Rendered.markup tape)))
  in
  print_string (Printf.sprintf "{\"pages\":[%s],\"effects\":%d}" (String.concat "," pages) (Rendered.effects ()))
