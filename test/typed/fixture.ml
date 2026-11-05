type status = Active | Done

type item = { id : int; title : string; status : status }

type model = { items : item list; draft : string; next : int; seed : int }

type message = Type of string | Add | Flip of int | Ignore

external document : Dom.document = "document"

let update message model =
  let flip status = match status with Active -> Done | Done -> Active in
  match message with
  | Type draft -> { model with draft }
  | Add ->
      { model with items = { id = model.next; title = model.draft; status = Active } :: model.items; draft = ""; next = model.next + 1 }
  | Flip id ->
      { model with items = List.map (fun item -> if item.id = id then { item with status = flip item.status } else item) model.items }
  | Ignore -> model

let row item =
  ((li ~key:(string_of_int item.id)
      ~className:(match item.status with Active -> "" | Done -> "done")
      ~onClick:(Flip item.id)
      ~children:[ Html.text item.title ] ()) [@JSX])

let view { items; draft; _ } =
  ((section
      ~children:
        [
          ((input ~value:draft ~onInput:(fun text -> Type text) ()) [@JSX]);
          ((ul ~children:[ Html.list (List.map row items) ] ()) [@JSX]);
        ]
      ()) [@JSX])

let start root = Program.sandbox ~init:{ items = []; draft = ""; next = 0; seed = 7 } ~update ~view root
let _ = document
