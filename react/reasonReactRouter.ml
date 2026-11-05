[@@@alert "-hook"]


type url = { path : string list; hash : string; search : string }
type watcherID = unit -> unit

external location : Dom.window -> Dom.location = "location" [@@mel.get]
external pathname : Dom.location -> string = "pathname" [@@mel.get]
external fragment : Dom.location -> string = "hash" [@@mel.get]
external query : Dom.location -> string = "search" [@@mel.get]
external listen : Dom.window -> (_[@mel.as "popstate"]) -> (unit -> unit) -> unit = "addEventListener" [@@mel.send]
external forget : Dom.window -> (_[@mel.as "popstate"]) -> (unit -> unit) -> unit = "removeEventListener" [@@mel.send]
external dispatch : Dom.window -> Dom.event -> unit = "dispatchEvent" [@@mel.send]
external popstate : (_[@mel.as "popstate"]) -> unit -> Dom.event = "Event" [@@mel.new]

external push_state : Dom.history -> (_[@mel.as {json|null|json}]) -> (_[@mel.as ""]) -> href:string -> unit
  = "pushState"
[@@mel.send]

external replace_state : Dom.history -> (_[@mel.as {json|null|json}]) -> (_[@mel.as ""]) -> href:string -> unit
  = "replaceState"
[@@mel.send]

let search_of raw =
  match Js.String.split ~sep:"?" ~limit:2 raw with [| _; search |] -> search | _ -> ""

let dangerouslyGetInitialUrl ?serverUrlString () =
  let read field = Option.fold ~none:"" ~some:(fun window -> field (location window)) [%mel.external window] in
  let path =
    match Option.value serverUrlString ~default:(read pathname) with
    | "" | "/" -> []
    | raw ->
        let raw = match Js.String.split ~sep:"?" ~limit:2 raw with [| path; _ |] -> path | _ -> raw in
        List.filter (fun part -> String.length part <> 0) (Array.to_list (Js.String.split ~sep:"/" raw))
  in
  let hash = match read fragment with "" | "#" -> "" | raw -> Js.String.slice ~start:1 raw in
  { path; hash; search = search_of (Option.value serverUrlString ~default:(read query)) }

let announce change href =
  Option.iter
    (fun window ->
      Option.iter
        (fun history ->
          (match change with `Push -> push_state history ~href | `Replace -> replace_state history ~href);
          dispatch window (popstate ()))
        [%mel.external history])
    [%mel.external window]

let push href = announce `Push href
let replace href = announce `Replace href

let watchUrl callback =
  let watcher () = callback (dangerouslyGetInitialUrl ()) in
  Option.iter (fun window -> listen window watcher) [%mel.external window];
  watcher

let unwatchUrl watcher = Option.iter (fun window -> forget window watcher) [%mel.external window]
let url_cell = Melact_runtime.Hook.key ()
let watch_cell = Melact_runtime.Hook.key ()

let useUrl ?serverUrl () =
  let url, setUrl = React.useState url_cell (fun () -> Option.value serverUrl ~default:(dangerouslyGetInitialUrl ())) in
  React.useEffect0 watch_cell (fun () ->
      let watcher = watchUrl (fun url -> setUrl (fun _ -> url)) in
      let fresh = dangerouslyGetInitialUrl () in
      (match
         ( String.equal fresh.hash url.hash,
           String.equal fresh.search url.search,
           List.equal String.equal fresh.path url.path )
       with
      | true, true, true -> ()
      | _ -> setUrl (fun _ -> fresh));
      Some (fun () -> unwatchUrl watcher));
  url
