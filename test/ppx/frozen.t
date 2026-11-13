Whether the value a let binds is only read afterwards, so that melact-ppx may keep it from an
earlier render. Every case asks about `v`:

  $ ./frozen.exe
  v                                                              possibly changed
  (div ~children:[ React.array v ] ()) [@JSX]                    read only
  (Row.createElement ~items:v ~children:[] ()) [@JSX]            read only
  v |. Belt.Array.keep (fun x -> x > 1) |. Belt.Array.length     read only
  List.length v + Array.length v                                 read only
  match v with [||] -> 0 | _ -> 1                                read only
  if v = [||] then 0 else 1                                      read only
  v.(0)                                                          read only
  v.(0) <- 1                                                     possibly changed
  v := 1                                                         possibly changed
  incr v                                                         possibly changed
  v.field                                                        read only
  v.field <- 1                                                   possibly changed
  Js.Array.push ~value:1 v                                       possibly changed
  Js.Array.map ~f:(fun x -> x) v                                 read only
  React.useEffect1 (fun () -> None) [| v |]                      read only
  unknown v                                                      possibly changed
  useCustom v                                                    read only
  use_custom v                                                   read only
  user v                                                         possibly changed
  useless v                                                      possibly changed
  (v, 1)                                                         possibly changed
  { items = v }                                                  possibly changed
  let w = v in w                                                 possibly changed
  let v = [||] in Js.Array.push ~value:1 v                       read only
  fun v -> v := 1                                                read only
  fun () -> Js.Array.push ~value:1 v                             possibly changed
  fun () -> Array.length v                                       read only
  match x with Some v -> v := 1 | None -> ()                     read only
  match x with Some w -> w := 1 | None -> v := 2                 possibly changed
