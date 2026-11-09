open Melhole
open Testing

external mouse : string -> < bubbles : bool ; relatedTarget : Dom.element Js.null > Js.t -> Dom.event = "MouseEvent"
[@@mel.new]

external dispatched : Dom.element -> Dom.event -> bool = "dispatchEvent" [@@mel.send]
external remove : Dom.element -> unit = "remove" [@@mel.send]

let entered = ref []

let listened element =
  ignore (Events.register element "pointerenter");
  Events.set element (Events.key_of "pointerenter") (fun _ -> entered := element :: !entered)

let chain depth =
  let rec nest parent level made =
    match level = depth with
    | true -> List.rev made
    | false ->
        let element = create_element document "div" in
        append_child parent element;
        listened element;
        nest element (level + 1) (element :: made)
  in
  let holder = create_element document "div" in
  (holder, nest holder 0 [])

let enter outermost_first =
  entered := [];
  let innermost = List.nth outermost_first (List.length outermost_first - 1) in
  ignore (dispatched innermost (mouse "pointerover" [%mel.obj { bubbles = true; relatedTarget = Js.null }]));
  List.iter
    (fun element -> ignore (dispatched element (mouse "pointerenter" [%mel.obj { bubbles = false; relatedTarget = Js.null }])))
    outermost_first;
  List.rev !entered

let () =
  describe "Entering elements listened to on themselves and then from the document" (fun () ->
      let before = List.map chain [ 1; 2; 3 ] in
      test "before the document listens, each element gets its own event once, outermost first" (fun () ->
          List.iter
            (fun (holder, elements) ->
              append_child (body document) holder;
              let seen = enter elements in
              remove holder;
              expect (List.length seen, List.for_all2 same seen elements) |. to_equal (List.length elements, true))
            before);
      test
        "once it listens, elements listened to before and after, nested either way, get it once, outermost first"
        (fun () ->
          ignore (Events.delegate_crossing "pointerenter");
          check
            (property (tapes ~shortest:3 ~longest:20) (fun values ->
                 let tape = tape values in
                 let holder, old = List.nth before (draw tape 3) in
                 let fresh_holder, fresh = chain (1 + draw tape 3) in
                 let root = attached () in
                 let outermost_first =
                   match draw tape 2 with
                   | 0 ->
                       append_child root fresh_holder;
                       append_child (List.nth fresh (List.length fresh - 1)) holder;
                       fresh @ old
                   | _ ->
                       append_child root holder;
                       append_child (List.nth old (List.length old - 1)) fresh_holder;
                       old @ fresh
                 in
                 let seen = enter outermost_first in
                 remove holder;
                 remove fresh_holder;
                 remove root;
                 expect (List.length seen, List.for_all2 same seen outermost_first)
                 |. to_equal (List.length outermost_first, true)))
            [%mel.obj { numRuns = 200 }]))
