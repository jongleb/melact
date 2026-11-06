[@@@alert "-hook"]

open Melhole
open Melact_runtime
open Testing

external test_async : string -> (unit -> unit Js.Promise.t) -> unit = "test"

let events = ref []
let log event = events := event :: !events

let take () =
  let taken = List.rev !events in
  events := [];
  taken


let fresh child =
  events := [];
  let root = attached () in
  let mounted = View.mount child ~parent:root ~before:None in
  Instance.settle ();
  (root, mounted)

let button =
  Template.make ~html:"<button></button>" ~holes:[| Handler ([], "click"); Text ([], 0) |]

let counter_def = Component.make ~name:"Counter"
let count_key = Hook.key ()

let counter label =
  Instance.component counter_def [| View.Input label |] (fun () ->
      log ("render " ^ label);
      let count, set = React.useState count_key (fun () -> 0) in
      View.tpl_instance button
        [| HHandler (fun _ -> set (fun n -> n + 1)); HText (label ^ string_of_int count) |])

let pair_def = Component.make ~name:"Pair"
let pair_key = Hook.key ()
let set_pair = ref (fun (_ : int -> int) -> ())

let pair () =
  Instance.component pair_def [||] (fun () ->
      log "render pair";
      let n, set = React.useState pair_key (fun () -> 0) in
      set_pair := set;
      View.list [ counter "fixed"; counter (if n > 0 then "moved" else "fixed ") ])

let effects_def = Component.make ~name:"Effects"
let layout_key = Hook.key ()
let passive_key = Hook.key ()
let deps_key = Hook.key ()

let effects name deps =
  Instance.component effects_def [| View.Input name; View.Input deps |] (fun () ->
      React.useLayoutEffect0 layout_key (fun () ->
          log ("layout " ^ name);
          Some (fun () -> log ("layout cleanup " ^ name)));
      React.useEffect0 passive_key (fun () ->
          log ("passive " ^ name);
          Some (fun () -> log ("passive cleanup " ^ name)));
      React.useEffect1 deps_key
        (fun () ->
          log ("deps " ^ name);
          Some (fun () -> log ("deps cleanup " ^ name)))
        deps;
      View.empty)

let parent_def = Component.make ~name:"Parent"
let parent_key = Hook.key ()
let set_parent = ref (fun (_ : string -> string) -> ())

let parent () =
  Instance.component parent_def [||] (fun () ->
      let dep, set = React.useState parent_key (fun () -> "a") in
      set_parent := set;
      View.list [ effects "child" [| "x" |]; effects "parent" [| dep |] ])

let memo_def = Component.make ~name:"Memo"
let memo_key = Hook.key ()
let ref_key = Hook.key ()
let reducer_key = Hook.key ()
let dispatch = ref (fun (_ : [ `Add of int | `Same ]) -> ())

let memo () =
  Instance.component memo_def [||] (fun () ->
      let total, send =
        React.useReducer reducer_key
          (fun total action -> match action with `Add n -> total + n | `Same -> total)
          0
      in
      dispatch := send;
      let parity =
        React.useMemo1 memo_key
          (fun () ->
            log "compute";
            if total mod 2 = 0 then "even" else "odd")
          [| total mod 2 |]
      in
      let renders = React.useRef ref_key 0 in
      renders.current <- renders.current + 1;
      View.text (Printf.sprintf "%d %s %d" total parity renders.current))

let theme = React.createContext "light"
let leaf_def = Component.make ~name:"Leaf"
let middle_def = Component.make ~name:"Middle"
let themed_def = Component.make ~name:"Themed"
let theme_key = Hook.key ()
let set_theme = ref (fun (_ : string -> string) -> ())

let leaf () =
  Instance.component leaf_def [||] (fun () ->
      log "render leaf";
      View.text (React.useContext theme))

let middle () =
  Instance.component middle_def [||] (fun () ->
      log "render middle";
      leaf ())

let themed () =
  Instance.component themed_def [||] (fun () ->
      log "render themed";
      let value, set = React.useState theme_key (fun () -> "dark") in
      set_theme := set;
      React.to_child (React.Context.provider theme (React.Context.makeProps ~value ~children:(React.of_child (middle ())) ())))

let toggle_def = Component.make ~name:"Toggle"
let toggle_key = Hook.key ()
let set_toggle = ref (fun (_ : bool -> bool) -> ())

let toggle () =
  Instance.component toggle_def [||] (fun () ->
      let shown, set = React.useState toggle_key (fun () -> false) in
      set_toggle := set;
      if shown then View.list [ View.text "A"; View.text "B" ] else View.empty)

let order_def = Component.make ~name:"Order"
let first_key = Hook.key ()
let second_key = Hook.key ()
let other_key = Hook.key ()
let flip = ref (fun (_ : bool -> bool) -> ())

let order () =
  Instance.component order_def [||] (fun () ->
      let flipped, set = React.useState first_key (fun () -> false) in
      flip := set;
      if flipped then ignore (React.useRef other_key 0)
      else ignore (React.useState second_key (fun () -> 0));
      View.empty)

let eager_def = Component.make ~name:"Eager"
let eager_key = Hook.key ()

let eager () =
  Instance.component eager_def [||] (fun () ->
      let _, set = React.useState eager_key (fun () -> 0) in
      set (fun n -> n + 1);
      View.empty)

let () =
  describe "useState" (fun () ->
      test_async "batches updates into one render per microtask" (fun () ->
          let root = attached () in
          let mounted = View.mount (counter "n=") ~parent:root ~before:None in
          Instance.settle ();
          ignore (take ());
          let element = select root "button" in
          click element;
          click element;
          let before = inner_html root in
          Js.Promise.then_
            (fun () ->
              expect (before, inner_html root, take ())
              |. to_equal ("<button>n=0</button>", "<button>n=2</button>", [ "render n=" ]);
              View.unmount mounted;
              Js.Promise.resolve ())
            (Js.Promise.resolve ()));
      test "skips a render when the value is unchanged" (fun () ->
          let _, _ = fresh (pair ()) in
          ignore (take ());
          !set_pair (fun n -> n);
          Instance.flush ();
          expect (take ()) |. to_equal []);
      test "re-renders only the component whose state changed" (fun () ->
          let root, _ = fresh (pair ()) in
          ignore (take ());
          click (select root "button");
          Instance.flush ();
          expect (take (), inner_html root)
          |. to_equal ([ "render fixed" ], "<button>fixed1</button><button>fixed 0</button>"));
      test "skips children whose props are unchanged" (fun () ->
          let root, _ = fresh (pair ()) in
          ignore (take ());
          !set_pair (fun n -> n + 1);
          Instance.flush ();
          expect (take (), inner_html root)
          |. to_equal
               ([ "render pair"; "render moved" ], "<button>fixed0</button><button>moved0</button>"));
      test "keeps the state of keyed components when they move" (fun () ->
          let row label = View.with_key label (counter label) in
          let root, mounted = fresh (View.list [ row "a"; row "b" ]) in
          click (select root "button");
          Instance.flush ();
          View.patch mounted (View.list [ row "b"; row "a" ]);
          Instance.settle ();
          expect (inner_html root) |. to_be "<button>b0</button><button>a1</button>");
      test "does nothing for an unmounted component" (fun () ->
          let _, mounted = fresh (pair ()) in
          View.unmount mounted;
          ignore (take ());
          !set_pair (fun n -> n + 1);
          Instance.flush ();
          expect (take ()) |. to_equal []));
  describe "effects" (fun () ->
      test "run children first, layout before passive" (fun () ->
          let _ = fresh (parent ()) in
          Instance.flush ();
          expect (take ())
          |. to_equal
               [
                 "layout child"; "layout parent"; "passive child"; "deps child"; "passive parent";
                 "deps parent";
               ]);
      test "compare dependencies element-wise and clean up before running again" (fun () ->
          let _ = fresh (parent ()) in
          Instance.flush ();
          ignore (take ());
          !set_parent (fun dep -> dep);
          Instance.flush ();
          expect (take ()) |. to_equal [];
          !set_parent (fun _ -> "b");
          Instance.flush ();
          expect (take ()) |. to_equal [ "deps cleanup parent"; "deps parent" ]);
      test "clean up on unmount, children before parents" (fun () ->
          let _, mounted = fresh (parent ()) in
          Instance.flush ();
          ignore (take ());
          View.unmount mounted;
          expect (take ())
          |. to_equal
               [
                 "layout cleanup child"; "passive cleanup child"; "deps cleanup child";
                 "layout cleanup parent"; "passive cleanup parent"; "deps cleanup parent";
               ]));
  describe "useReducer, useMemo and useRef" (fun () ->
      test "recompute only when dependencies change" (fun () ->
          let root, _ = fresh (memo ()) in
          !dispatch (`Add 2);
          Instance.flush ();
          !dispatch (`Add 1);
          Instance.flush ();
          !dispatch `Same;
          Instance.flush ();
          expect (take (), inner_html root) |. to_equal ([ "compute"; "compute" ], "3 odd 3")));
  describe "context" (fun () ->
      test "reads the default without a provider" (fun () ->
          let root, _ = fresh (leaf ()) in
          expect (inner_html root) |. to_be "light");
      test "re-renders consumers below skipped components" (fun () ->
          let root, _ = fresh (themed ()) in
          ignore (take ());
          !set_theme (fun _ -> "blue");
          Instance.flush ();
          expect (take (), inner_html root) |. to_equal ([ "render themed"; "render leaf" ], "blue")));
  describe "components" (fun () ->
      test "hold their place while they render nothing" (fun () ->
          let root, _ = fresh (View.list [ View.text "<"; toggle (); View.text ">" ]) in
          !set_toggle (fun _ -> true);
          Instance.flush ();
          let shown = inner_html root in
          !set_toggle (fun _ -> false);
          Instance.flush ();
          !set_toggle (fun _ -> true);
          Instance.flush ();
          expect (shown, inner_html root) |. to_equal ("&lt;AB&gt;", "&lt;AB&gt;"));
      test "reject hooks called in a different order" (fun () ->
          let _ = fresh (order ()) in
          !flip (fun _ -> true);
          expect (fun () -> Instance.flush ()) |. to_throw "different order");
      test "reject a setter called while rendering" (fun () ->
          expect (fun () -> fresh (eager ())) |. to_throw "while a component was rendering"))
