open Melhole
open Testing

open Trees

let distinct_keys tape =
  let chosen = List.filter (fun _ -> draw tape 3 > 0) (List.init 10 (fun i -> "k" ^ string_of_int i)) in
  let ranked = List.map (fun key -> (draw tape 1000, key)) chosen in
  List.map snd (List.stable_sort compare ranked)

let rows keys =
  View.keyed (List.map (fun key -> (key, View.tpl_instance row [| HAttr (Some key); HText key |])) keys)

let () =
  describe "View laws" (fun () ->
      test "patching is observationally equal to mounting from scratch" (fun () ->
          check
            (property
               (array_of (tapes ~shortest:8 ~longest:60) [%mel.obj { minLength = 1; maxLength = 6 }])
               (fun sequence ->
                 let root = create_element document "div" in
                 let mounted = View.mount View.empty ~parent:root ~before:None in
                 Array.iter
                   (fun values ->
                     let child = decode values in
                     View.patch mounted child;
                     expect (shapes (as_node root)) |. to_equal (rendered child))
                   sequence;
                 View.unmount mounted))
            [%mel.obj { numRuns = 400 }]);
      test "patching with an equal description writes nothing to the DOM" (fun () ->
          check
            (property (tapes ~shortest:8 ~longest:80) (fun values ->
                 let root = create_element document "div" in
                 let mounted = View.mount (decode values) ~parent:root ~before:None in
                 let watcher = observer (fun () -> ()) in
                 observe watcher root
                   [%mel.obj { childList = true; subtree = true; attributes = true; characterData = true }];
                 View.patch mounted (decode values);
                 let records = Array.length (take_records watcher) in
                 disconnect watcher;
                 View.unmount mounted;
                 expect records |. to_be 0))
            [%mel.obj { numRuns = 400 }]);
      test "unmounting removes every node and every listener it added" (fun () ->
          check
            (property (tapes ~shortest:8 ~longest:80) (fun values ->
                 let root = create_element document "div" in
                 let adds = spy_on event_target_prototype "addEventListener" in
                 let removes = spy_on event_target_prototype "removeEventListener" in
                 let mounted = View.mount (decode values) ~parent:root ~before:None in
                 View.unmount mounted;
                 let own spy =
                   Array.length
                     (Array.of_list
                        (List.filter
                           (fun context -> not (same context document))
                           (Array.to_list (contexts (mock spy)))))
                 in
                 let added = own adds and removed = own removes in
                 restore adds;
                 restore removes;
                 expect (Array.length (nodes (child_nodes root)), added) |. to_equal (0, removed)))
            [%mel.obj { numRuns = 300 }]);
      test "keyed rows keep their nodes and move exactly n - LIS of them" (fun () ->
          check
            (property (tapes ~shortest:40 ~longest:60) (fun values ->
                 let tape = tape values in
                 let before = distinct_keys tape and after = distinct_keys tape in
                 let root = create_element document "ul" in
                 let mounted = View.mount (rows before) ~parent:root ~before:None in
                 let node_of key = select root (Printf.sprintf "li[data-key=%s]" key) in
                 let old_nodes = List.map (fun key -> (key, node_of key)) before in
                 let inserts = spy_on node_prototype "insertBefore" in
                 View.patch mounted (rows after);
                 let moved =
                   List.length
                     (List.sort_uniq compare
                        (List.filter_map
                           (fun arguments ->
                             List.find_map
                               (fun (key, node) -> if same node arguments.(0) then Some key else None)
                               old_nodes)
                           (Array.to_list (calls (mock inserts)))))
                 in
                 restore inserts;
                 let common = List.filter (fun key -> List.mem key before) after in
                 let order =
                   Array.to_list (Array.map (fun node -> attribute node "data-key") (nodes (child_nodes root)))
                 in
                 expect
                   ( order,
                     List.for_all (fun key -> same (node_of key) (List.assoc key old_nodes)) common,
                     moved )
                 |. to_equal
                      ( after,
                        true,
                        List.length common
                        - longest_increasing
                            (List.map
                               (fun key ->
                                 let rec index position keys =
                                   match keys with
                                   | [] -> position
                                   | other :: rest -> if String.equal other key then position else index (position + 1) rest
                                 in
                                 index 0 before)
                               common) )))
            [%mel.obj { numRuns = 400 }]))
