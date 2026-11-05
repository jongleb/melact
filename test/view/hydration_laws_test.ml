open Melhole
open Testing
open Trees

external select_all : Dom.element -> string -> Dom.nodeList = "querySelectorAll" [@@mel.send]
external set_inner_html : Dom.element -> string -> unit = "innerHTML" [@@mel.set]
external document_prototype : prototype = "prototype" [@@mel.scope "Document"]

let markers root =
  let rec count node =
    Array.fold_left
      (fun total child ->
        total
        + (match node_type child with 8 -> 1 | _ -> 0)
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
      test "hydrating the server's HTML shows what mounting shows, and leaves no comment behind" (fun () ->
          check
            (property (tapes ~shortest:8 ~longest:80) (fun values ->
                 let child = decode values in
                 let root = served child in
                 let mounted = Served.hydrate child ~parent:root in
                 let shown = shapes (as_node root) and left = markers root in
                 View.unmount mounted;
                 expect (shown, left) |. to_equal (rendered (decode values), 0)))
            [%mel.obj { numRuns = 400 }]);
      test "hydration keeps every element the server sent and creates none" (fun () ->
          check
            (property (tapes ~shortest:8 ~longest:80) (fun values ->
                 let child = decode values in
                 let root = served child in
                 let before = nodes (select_all root "*") in
                 let creates = spy_on document_prototype "createElement" in
                 let clones = spy_on node_prototype "cloneNode" in
                 let mounted = Served.hydrate child ~parent:root in
                 let created = Array.length (calls (mock creates)) + Array.length (calls (mock clones)) in
                 restore creates;
                 restore clones;
                 let after = nodes (select_all root "*") in
                 let kept =
                   Array.length before = Array.length after
                   && Array.for_all (fun node -> Array.exists (fun other -> same node other) after) before
                 in
                 View.unmount mounted;
                 expect (created, kept) |. to_equal (0, true)))
            [%mel.obj { numRuns = 400 }]);
      test "after hydration, patching shows what mounting shows" (fun () ->
          check
            (property
               (array_of (tapes ~shortest:8 ~longest:60) [%mel.obj { minLength = 2; maxLength = 5 }])
               (fun sequence ->
                 let first = decode sequence.(0) in
                 let root = served first in
                 let mounted = Served.hydrate first ~parent:root in
                 let seen =
                   Array.to_list
                     (Array.map
                        (fun values ->
                          View.patch mounted (decode values);
                          (shapes (as_node root), rendered (decode values)))
                        (Array.sub sequence 1 (Array.length sequence - 1)))
                 in
                 View.unmount mounted;
                 expect (List.map fst seen) |. to_equal (List.map snd seen)))
            [%mel.obj { numRuns = 300 }]))
