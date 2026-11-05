open Melhole
open Testing
open Trees

external select_all : Dom.element -> string -> Dom.nodeList = "querySelectorAll" [@@mel.send]
external set_inner_html : Dom.element -> string -> unit = "innerHTML" [@@mel.set]

external node_value_of : Dom.node -> string = "nodeValue" [@@mel.get]
external previous : Dom.node -> Dom.node Js.null = "previousSibling" [@@mel.get]
external following : Dom.node -> Dom.node Js.null = "nextSibling" [@@mel.get]

let texty node = Option.fold ~none:false ~some:(fun found -> node_type found = 3) (Js.Null.toOption node)

let markers root =
  let rec count node =
    Array.fold_left
      (fun total child ->
        total
        + (match node_type child with
          | 8 when String.equal (node_value_of child) " " && texty (previous child) && texty (following child) -> 0
          | 8 -> 1
          | _ -> 0)
        + count child)
      0 (nodes (node_children node))
  in
  count (as_node root)

let served child =
  let root = create_element document "div" in
  set_inner_html root (Served.render child);
  root

let () =
  describe "Hydration laws" (fun () ->
      test "hydrating the server's HTML shows what mounting shows, and the only comments left separate two texts" (fun () ->
          check
            (property (tapes ~shortest:8 ~longest:80) (fun values ->
                 let child = decode values in
                 let root = served child in
                 let mounted = Served.hydrate child ~parent:root in
                 let shown = shapes (as_node root) and left = markers root in
                 View.unmount mounted;
                 expect (shown, left) |. to_equal (rendered (decode values), 0)))
            [%mel.obj { numRuns = 400 }]);
      test "after hydration the page holds exactly the elements the server sent" (fun () ->
          check
            (property (tapes ~shortest:8 ~longest:80) (fun values ->
                 let child = decode values in
                 let root = served child in
                 let before = nodes (select_all root "*") in
                 let mounted = Served.hydrate child ~parent:root in
                 let after = nodes (select_all root "*") in
                 let sent node = Array.exists (fun other -> same node other) before in
                 let kept = Array.for_all (fun node -> Array.exists (fun other -> same node other) after) before in
                 let foreign = Array.length (Js.Array.filter ~f:(fun node -> not (sent node)) after) in
                 View.unmount mounted;
                 expect (foreign, kept) |. to_equal (0, true)))
            [%mel.obj { numRuns = 400 }]);
      test "after hydration, patching shows what mounting shows, for new trees and for edits of the first" (fun () ->
          check
            (property
               (array_of (tapes ~shortest:8 ~longest:60) [%mel.obj { minLength = 2; maxLength = 5 }])
               (fun sequence ->
                 let first = decode sequence.(0) in
                 let root = served first in
                 let mounted = Served.hydrate first ~parent:root in
                 let edited values =
                   match Array.length values with
                   | 0 -> values
                   | _ when values.(0) mod 2 = 0 -> values
                   | count ->
                       let copy = Array.copy sequence.(0) in
                       for index = 0 to ((count - 1) / 2) - 1 do
                         match Array.length copy with
                         | 0 -> ()
                         | length -> copy.(values.((2 * index) + 1) mod length) <- values.((2 * index) + 2)
                       done;
                       copy
                 in
                 let seen =
                   Array.to_list
                     (Array.map
                        (fun values ->
                          let values = edited values in
                          View.patch mounted (decode values);
                          (shapes (as_node root), rendered (decode values)))
                        (Array.sub sequence 1 (Array.length sequence - 1)))
                 in
                 View.unmount mounted;
                 expect (List.map fst seen) |. to_equal (List.map snd seen)))
            [%mel.obj { numRuns = 300 }]))
