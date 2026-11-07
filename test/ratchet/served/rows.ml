let made count =
  let words = [| "pretty"; "large"; "small"; "quaint"; "elegant"; "angry"; "helpful"; "odd" |] in
  let things = [| "table"; "chair"; "house"; "desk"; "pony"; "cookie"; "keyboard"; "mouse" |] in
  Array.init count (fun index ->
      { Page.id = index + 1; label = words.(index mod 8) ^ " " ^ things.(index * 7 mod 8) ^ " " ^ string_of_int index })
