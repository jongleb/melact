open Melhole
open Testing

let row = Template.make ~html:"<li></li>" ~holes:[| Text ([], 0) |]
let rows labels = View.keyed (List.map (fun (key, label) -> (key, View.tpl_instance row [| HText label |])) labels)
let numbered count = List.init count (fun i -> (string_of_int i, string_of_int i))

let describe_steps (plan : Reconcile.t) =
  Array.to_list
    (Array.map
       (fun step ->
         match step with
         | Reconcile.Keep i -> "keep " ^ string_of_int i
         | Move i -> "move " ^ string_of_int i
         | Create -> "create")
       plan.steps)

let () =
  describe "plan" (fun () ->
      test "keeps prefix and suffix" (fun () ->
          let plan = Reconcile.plan ~old:[| "a"; "b"; "c" |] ~next:[| "a"; "x"; "c" |] in
          expect (describe_steps plan, plan.dropped)
          |. to_equal ([ "keep 0"; "create"; "keep 2" ], [ 1 ]));
      test "moves only the swapped entries" (fun () ->
          let plan =
            Reconcile.plan ~old:[| "a"; "b"; "c"; "d"; "e"; "f" |]
              ~next:[| "a"; "e"; "c"; "d"; "b"; "f" |]
          in
          expect (describe_steps plan)
          |. to_equal
               [ "keep 0"; "move 4"; "keep 2"; "keep 3"; "move 1"; "keep 5" ]);
      test "reverses with one fewer move than entries" (fun () ->
          let plan = Reconcile.plan ~old:[| "a"; "b"; "c" |] ~next:[| "c"; "b"; "a" |] in
          expect (describe_steps plan) |. to_equal [ "move 2"; "move 1"; "keep 0" ]);
      test "never reuses an old entry twice for duplicate keys" (fun () ->
          let plan = Reconcile.plan ~old:[| "a"; "b" |] ~next:[| "b"; "b"; "b" |] in
          expect (describe_steps plan, plan.dropped)
          |. to_equal ([ "create"; "create"; "keep 1" ], [ 0 ])));
  describe "keyed rows" (fun () ->
      let mounted_rows labels =
        let root = create_element document "ul" in
        (root, View.mount (rows labels) ~parent:root ~before:None)
      in
      let texts root = Array.to_list (Array.map text_content (nodes (child_nodes root))) in
      let kept before after =
        List.length (List.filter (fun node -> List.exists (same node) after) before)
      in
      test "create 1000, append 1000, update every 10th" (fun () ->
          let root, mounted = mounted_rows (numbered 1000) in
          let created = Array.to_list (nodes (child_nodes root)) in
          View.patch mounted (rows (numbered 2000));
          let appended = Array.to_list (nodes (child_nodes root)) in
          expect (List.length appended, kept created appended) |. to_equal (2000, 1000);
          View.patch mounted
            (rows
               (List.map
                  (fun (key, label) ->
                    (key, if int_of_string key mod 10 = 0 then label ^ " !!!" else label))
                  (numbered 2000)));
          expect (kept appended (Array.to_list (nodes (child_nodes root)))) |. to_be 2000;
          expect (List.nth (texts root) 10, List.nth (texts root) 11)
          |. to_equal ("10 !!!", "11"));
      test "swap two rows with two moves" (fun () ->
          let labels = numbered 1000 in
          let root, mounted = mounted_rows labels in
          let swapped =
            List.mapi
              (fun i entry ->
                match i with 1 -> List.nth labels 998 | 998 -> List.nth labels 1 | _ -> entry)
              labels
          in
          let moves =
            count_calls (spy_on node_prototype "insertBefore") (fun () ->
                View.patch mounted (rows swapped))
          in
          expect (moves, texts root) |. to_equal (2, List.map snd swapped));
      test "remove one row" (fun () ->
          let root, mounted = mounted_rows (numbered 1000) in
          let before = Array.to_list (nodes (child_nodes root)) in
          let remaining = List.filter (fun (key, _) -> key <> "500") (numbered 1000) in
          View.patch mounted (rows remaining);
          expect (texts root, kept before (Array.to_list (nodes (child_nodes root))))
          |. to_equal (List.map snd remaining, 999));
      test "reverse with n - 1 moves" (fun () ->
          let root, mounted = mounted_rows (numbered 1000) in
          let reversed = List.rev (numbered 1000) in
          let moves =
            count_calls (spy_on node_prototype "insertBefore") (fun () ->
                View.patch mounted (rows reversed))
          in
          expect (moves, texts root) |. to_equal (999, List.map snd reversed));
      test "replace all rows and clear" (fun () ->
          let root, mounted = mounted_rows (numbered 1000) in
          let before = Array.to_list (nodes (child_nodes root)) in
          let fresh = List.map (fun (key, label) -> ("new" ^ key, label)) (numbered 1000) in
          View.patch mounted (rows fresh);
          expect (kept before (Array.to_list (nodes (child_nodes root)))) |. to_be 0;
          View.patch mounted (rows []);
          expect (inner_html root) |. to_be ""))
