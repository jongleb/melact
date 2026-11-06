type url = { path : string list; hash : string; search : string }
type watcherID = Watching

let push _ = ()
let replace _ = ()
let watchUrl _ = Watching
let unwatchUrl Watching = ()

let dangerouslyGetInitialUrl ?(serverUrlString = "") () =
  let path, search =
    match String.index_opt serverUrlString '?' with
    | Some at -> (String.sub serverUrlString 0 at, String.sub serverUrlString (at + 1) (String.length serverUrlString - at - 1))
    | None -> (serverUrlString, "")
  in
  { path = List.filter (fun part -> String.length part <> 0) (String.split_on_char '/' path); hash = ""; search }

let useUrl ?serverUrl () = Option.value serverUrl ~default:(dangerouslyGetInitialUrl ())
