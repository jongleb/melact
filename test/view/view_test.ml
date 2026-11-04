open Melhole
open Testing

let paragraph =
  Template.make ~html:"<p class=\"static\"><b>bold</b></p>"
    ~holes:
      [| Attr ([], "title"); Text ([ 0 ], 1); Child ([], 0); Child ([], 1) |]

let other = Template.make ~html:"<em></em>" ~holes:[||]
let em = View.tpl_instance other [||]

let fresh child =
  let root = create_element document "div" in
  (root, View.mount child ~parent:root ~before:None)

let () =
  describe "text" (fun () ->
      test "patches the same node" (fun () ->
          let root, mounted = fresh (View.text "a") in
          let node = (nodes (child_nodes root)).(0) in
          View.patch mounted (View.text "b");
          expect (inner_html root) |. to_be "b";
          expect (same (nodes (child_nodes root)).(0) node) |. to_be true);
      test "is replaced by another kind" (fun () ->
          let root, mounted = fresh (View.text "a") in
          View.patch mounted em;
          expect (inner_html root) |. to_be "<em></em>";
          View.patch mounted View.empty;
          expect (inner_html root) |. to_be "";
          View.patch mounted (View.list [ View.text "x"; View.text "y" ]);
          expect (inner_html root) |. to_be "xy";
          View.patch mounted (View.text "z");
          expect (inner_html root) |. to_be "z"));
  describe "template instance" (fun () ->
      let instance title text before after =
        View.tpl_instance paragraph
          [| HAttr title; HText text; HChild before; HChild after |]
      in
      test "fills every hole kind position" (fun () ->
          let root, _ =
            fresh (instance (Some "t") "!" (View.text "<") (View.text ">"))
          in
          expect (inner_html root)
          |. to_be "<p class=\"static\" title=\"t\">&lt;<b>bold!</b>&gt;</p>");
      test "writes only changed holes" (fun () ->
          let before = View.text "<" and after = View.text ">" in
          let root, mounted = fresh (instance (Some "t") "!" before after) in
          let paragraph = select root "p" in
          let writes =
            count_calls (spy_on element_prototype "setAttribute") (fun () ->
                View.patch mounted (instance (Some "t") "?" before after))
          in
          expect writes |. to_be 0;
          expect (inner_html root)
          |. to_be "<p class=\"static\" title=\"t\">&lt;<b>bold?</b>&gt;</p>";
          View.patch mounted (instance (Some "u") "?" before after);
          expect (same (select root "p") paragraph) |. to_be true;
          expect (inner_html root)
          |. to_be "<p class=\"static\" title=\"u\">&lt;<b>bold?</b>&gt;</p>");
      test "removes an attribute set to None" (fun () ->
          let root, mounted =
            fresh (instance (Some "t") "" View.empty View.empty)
          in
          View.patch mounted (instance None "" View.empty View.empty);
          expect (inner_html root)
          |. to_be "<p class=\"static\"><b>bold</b></p>");
      test "keeps child holes in place as they grow" (fun () ->
          let root, mounted = fresh (instance None "" View.empty View.empty) in
          View.patch mounted
            (instance None "" (View.list [ View.text "1"; View.text "2" ]) em);
          expect (inner_html root)
          |. to_be "<p class=\"static\">12<b>bold</b><em></em></p>";
          View.patch mounted
            (instance None "" (View.text "3")
               (View.list [ em; View.text "4" ]));
          expect (inner_html root)
          |. to_be "<p class=\"static\">3<b>bold</b><em></em>4</p>");
      test "is replaced by another template" (fun () ->
          let root, mounted = fresh (instance None "" View.empty View.empty) in
          View.patch mounted em;
          expect (inner_html root) |. to_be "<em></em>");
      test "rejects a hole value of the wrong kind" (fun () ->
          expect (fun () -> fresh (View.tpl_instance other [| HText "x" |]))
          |. to_throw "expects 0 hole values, got 1";
          expect (fun () ->
              fresh
                (View.tpl_instance paragraph
                   [| HText ""; HText ""; HChild em; HChild em |]))
          |. to_throw "does not match");
      test "rejects a path outside the template" (fun () ->
          let broken =
            Template.make ~html:"<p></p>" ~holes:[| Attr ([ 3 ], "id") |]
          in
          expect (fun () -> fresh (View.tpl_instance broken [| HAttr None |]))
          |. to_throw "does not resolve"));
  describe "properties, styles, classes and refs" (fun () ->
      let input =
        Template.make ~html:"<input>"
          ~holes:[| Prop ([], "value"); Style []; Class_list []; Ref [] |]
      in
      let instance value style classes ref =
        View.tpl_instance input
          [| HProp value; HStyle style; HClass classes; HRef ref |]
      in
      test "are written and replaced" (fun () ->
          let refs = ref [] in
          let first element = refs := ("first", element) :: !refs in
          let second element = refs := ("second", element) :: !refs in
          let root, mounted =
            fresh (instance "a" [ ("color", "red") ] [ "x"; "y" ] first)
          in
          let element = select root "input" in
          expect (dom_property element "value") |. to_be "a";
          expect (style_property (style element) "color") |. to_be "red";
          expect (inner_html root)
          |. to_be "<input style=\"color: red;\" class=\"x y\">";
          View.patch mounted (instance "b" [ ("width", "1px") ] [ "y" ] first);
          expect (dom_property element "value") |. to_be "b";
          expect (inner_html root)
          |. to_be "<input style=\"width: 1px;\" class=\"y\">";
          View.patch mounted (instance "b" [ ("width", "1px") ] [ "y" ] second);
          expect (List.map fst !refs) |. to_equal [ "second"; "first" ];
          expect (List.for_all (fun (_, seen) -> same seen element) !refs)
          |. to_be true));
  describe "handlers" (fun () ->
      let button =
        Template.make ~html:"<div><button></button></div>"
          ~holes:[| Handler ([], "click"); Handler ([ 0 ], "click") |]
      in
      test "are replaced without DOM writes" (fun () ->
          let root = attached () in
          let seen = ref [] in
          let log name _ = seen := name :: !seen in
          let mounted =
            View.mount
              (View.tpl_instance button [| HHandler (log "outer"); HHandler (log "a") |])
              ~parent:root ~before:None
          in
          let writes =
            count_calls (spy_on element_prototype "setAttribute") (fun () ->
                View.patch mounted
                  (View.tpl_instance button
                     [| HHandler (log "outer"); HHandler (log "b") |]))
          in
          let listens =
            count_calls (spy_on event_target_prototype "addEventListener") (fun () ->
                View.patch mounted
                  (View.tpl_instance button
                     [| HHandler (log "outer"); HHandler (log "c") |]))
          in
          click (select root "button");
          expect (writes, listens) |. to_equal (0, 0);
          expect !seen |. to_equal [ "outer"; "c" ];
          View.unmount mounted);
      test "stop bubbling on stopPropagation" (fun () ->
          let root = attached () in
          let seen = ref [] in
          let mounted =
            View.mount
              (View.tpl_instance button
                 [|
                   HHandler (fun _ -> seen := "outer" :: !seen);
                   HHandler
                     (fun event ->
                       stop_propagation event;
                       seen := "inner" :: !seen);
                 |])
              ~parent:root ~before:None
          in
          click (select root "button");
          expect !seen |. to_equal [ "inner" ];
          View.unmount mounted);
      test "are removed on unmount" (fun () ->
          let root = attached () in
          let scrolls = ref 0 in
          let scroller =
            Template.make ~html:"<div></div>" ~holes:[| Handler ([], "scroll") |]
          in
          let mounted =
            View.mount
              (View.tpl_instance scroller [| HHandler (fun _ -> incr scrolls) |])
              ~parent:root ~before:None
          in
          let element = select root "div" in
          dispatch element (event "scroll");
          let removals =
            count_calls (spy_on event_target_prototype "removeEventListener") (fun () ->
                View.unmount mounted)
          in
          dispatch element (event "scroll");
          expect (!scrolls, removals, inner_html root) |. to_equal (1, 1, "")));
  describe "lazy" (fun () ->
      test "skips physically unchanged arguments" (fun () ->
          let forced = ref 0 in
          let render label =
            incr forced;
            View.text label
          in
          let root, mounted = fresh (View.lazy1 render "a") in
          View.patch mounted (View.lazy1 render "a");
          expect !forced |. to_be 1;
          View.patch mounted (View.lazy1 render "b");
          expect (!forced, inner_html root) |. to_equal (2, "b"));
      test "skips two unchanged arguments" (fun () ->
          let forced = ref 0 in
          let render a b =
            incr forced;
            View.text (a ^ b)
          in
          let root, mounted = fresh (View.lazy2 render "a" "b") in
          View.patch mounted (View.lazy2 render "a" "b");
          View.patch mounted (View.lazy2 render "a" "c");
          expect (!forced, inner_html root) |. to_equal (2, "ac")));
  describe "positional list" (fun () ->
      test "grows and shrinks at the tail" (fun () ->
          let root, mounted = fresh (View.list [ View.text "a"; View.text "b" ]) in
          let first = (nodes (child_nodes root)).(0) in
          View.patch mounted (View.list [ View.text "a"; View.text "b"; em ]);
          expect (inner_html root) |. to_be "ab<em></em>";
          View.patch mounted (View.list [ View.text "c" ]);
          expect (inner_html root) |. to_be "c";
          expect (same (nodes (child_nodes root)).(0) first) |. to_be true);
      test "unmount removes every node" (fun () ->
          let root, mounted =
            fresh (View.list [ View.text "a"; View.list [ em; em ]; View.empty ])
          in
          View.unmount mounted;
          expect (inner_html root) |. to_be ""))
