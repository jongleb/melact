open Melhole
open Testing

external use_fake_timers : < toFake : string array > Js.t -> unit = "useFakeTimers" [@@mel.scope "vi"]
external use_real_timers : unit -> unit = "useRealTimers" [@@mel.scope "vi"]
external advance : int -> unit = "advanceTimersByTime" [@@mel.scope "vi"]
external children : Dom.element -> Dom.htmlCollection = "children" [@@mel.get]
external elements : Dom.htmlCollection -> Dom.element array = "from" [@@mel.scope "Array"]
external class_name : Dom.element -> string = "className" [@@mel.get]
external text_of : Dom.element -> string = "textContent" [@@mel.get]
external transform : Dom.cssStyleDeclaration -> string = "transform" [@@mel.get]
external child_count : Dom.element -> int = "childElementCount" [@@mel.get]

let stub_rects : unit -> unit -> unit =
  [%mel.raw
    {|function () {
        const original = Element.prototype.getBoundingClientRect;
        Element.prototype.getBoundingClientRect = function () {
          const index = this.parentNode ? Array.prototype.indexOf.call(this.parentNode.children, this) : 0;
          return { left: 0, top: index * 20 };
        };
        return function () { Element.prototype.getBoundingClientRect = original; };
      }|}]

let animated : int -> unit -> unit =
  [%mel.raw
    {|function (count) {
        const original = Element.prototype.getAnimations;
        globalThis.__finish = [];
        Element.prototype.getAnimations = function () {
          const made = [];
          for (let i = 0; i < count; i++) {
            let done;
            const finished = new Promise((resolve) => { done = resolve; });
            globalThis.__finish.push(done);
            made.push({ finished });
          }
          return made;
        };
        return function () {
          if (original) Element.prototype.getAnimations = original;
          else delete Element.prototype.getAnimations;
        };
      }|}]

let finish_animation : int -> unit = [%mel.raw {|function (index) { globalThis.__finish[index](); }|}]
let drained : unit -> unit Js.Promise.t = [%mel.raw {|function () { return new Promise((resolve) => setTimeout(resolve, 0)); }|}]
external inert : Dom.element -> string -> string Js.null = "getAttribute" [@@mel.send]
external test_async : string -> (unit -> unit Js.Promise.t) -> unit = "test"
external use_real_timers_now : unit -> unit = "useRealTimers" [@@mel.scope "vi"]

let duration = 100
let keys = [| "a"; "b"; "c"; "d"; "e"; "f" |]
let plain = Template.make ~html:"<li></li>" ~holes:[| Text ([], 0) |]
let rows ?(template = plain) shown = View.keyed (List.map (fun key -> (key, View.tpl_instance template [| HText key |])) shown)

(** Which wrapper a run uses. *)
type wrapper = Single | Group

let wrapped wrapper shown =
  match wrapper with
  | Single -> Transition.make ~name:"t" ~duration (rows shown)
  | Group -> Transition.group ~name:"t" ~duration (rows shown)

let in_fake_time run =
  use_fake_timers
    [%mel.obj { toFake = [| "setTimeout"; "clearTimeout"; "requestAnimationFrame"; "cancelAnimationFrame"; "Date" |] }];
  match run () with
  | result ->
      use_real_timers ();
      result
  | exception error ->
      use_real_timers ();
      raise error

let shown_keys root = Array.to_list (Array.map text_of (elements (children root)))

let classes root =
  Array.to_list (Array.map (fun element -> (text_of element, class_name element)) (elements (children root)))

let subset tape = List.filter (fun _ -> draw tape 2 = 0) (Array.to_list keys)

let shuffle tape items =
  let pool = Array.of_list items in
  for index = Array.length pool - 1 downto 1 do
    let other = draw tape (index + 1) in
    let held = pool.(index) in
    pool.(index) <- pool.(other);
    pool.(other) <- held
  done;
  Array.to_list pool

let fresh shown =
  let root = create_element document "ul" in
  let mounted = View.mount (rows shown) ~parent:root ~before:None in
  let seen = shapes (as_node root) in
  View.unmount mounted;
  seen

let settled wrapper shown =
  let root = create_element document "ul" in
  (root, View.mount (wrapped wrapper shown) ~parent:root ~before:None)

let wrapper_of tape = match draw tape 2 with 0 -> Single | _ -> Group
let two_frames = 40

let () =
  describe "Transition laws" (fun () ->
      test "once every transition has ended, the page is what a fresh mount of the last list shows" (fun () ->
          check
            (property (tapes ~shortest:4 ~longest:60) (fun values ->
                 in_fake_time (fun () ->
                     let tape = tape values in
                     let wrapper = wrapper_of tape in
                     let root, mounted = settled wrapper (subset tape) in
                     let phases name =
                       List.length
                         (List.filter
                            (fun family -> Js.String.includes ~search:("t-" ^ family) name)
                            [ "enter"; "leave"; "move" ])
                     in
                     let rec run remaining last mixed =
                       match remaining with
                       | 0 -> (last, mixed)
                       | _ ->
                           let next = shuffle tape (subset tape) in
                           View.patch mounted (wrapped wrapper next);
                           advance [| 0; 10; 40; 150 |].(draw tape 4);
                           let mixed =
                             mixed + List.length (List.filter (fun (_, name) -> phases name > 1) (classes root))
                           in
                           run (remaining - 1) next mixed
                     in
                     let last, mixed = run (1 + draw tape 8) [] 0 in
                     advance (duration + 100);
                     let seen = shapes (as_node root) in
                     View.unmount mounted;
                     expect (seen, mixed) |. to_equal (fresh last, 0))))
            [%mel.obj { numRuns = 300 }]);
      test "a removed row stays where it was, leaving, until its time is up, then goes" (fun () ->
          check
            (property (tapes ~shortest:4 ~longest:30) (fun values ->
                 in_fake_time (fun () ->
                     let tape = tape values in
                     let wrapper = wrapper_of tape in
                     let start = shuffle tape (Array.to_list keys) in
                     let kept = List.filter (fun _ -> draw tape 3 > 0) start in
                     let root, mounted = settled wrapper start in
                     View.patch mounted (wrapped wrapper kept);
                     let leaving phase =
                       List.map
                         (fun key -> (key, match List.mem key kept with true -> "" | false -> phase))
                         start
                     in
                     let at_once = classes root in
                     let inert_keys =
                       List.filter_map
                         (fun element ->
                           Option.map (fun _ -> text_of element) (Js.Null.toOption (inert element "inert")))
                         (Array.to_list (elements (children root)))
                     in
                     advance two_frames;
                     let framed = classes root in
                     advance (duration - two_frames - 1);
                     let still = shown_keys root in
                     advance 50;
                     let after = shown_keys root in
                     View.unmount mounted;
                     expect (at_once, inert_keys, framed, still, after)
                     |. to_equal
                          ( leaving "t-leave-from t-leave-active",
                            List.filter (fun key -> not (List.mem key kept)) start,
                            leaving "t-leave-active t-leave-to",
                            start,
                            kept ))))
            [%mel.obj { numRuns = 200 }]);
      test "a new row enters with the enter classes, which are gone when its time is up" (fun () ->
          check
            (property (tapes ~shortest:4 ~longest:30) (fun values ->
                 in_fake_time (fun () ->
                     let tape = tape values in
                     let wrapper = wrapper_of tape in
                     let start = subset tape in
                     let next = shuffle tape (Array.to_list keys) in
                     let next = List.filter (fun key -> List.mem key start || draw tape 2 = 0) next in
                     let start = List.filter (fun key -> List.mem key start) next in
                     let root, mounted = settled wrapper start in
                     View.patch mounted (wrapped wrapper next);
                     let entering phase =
                       List.map (fun key -> (key, match List.mem key start with true -> "" | false -> phase)) next
                     in
                     let at_once = classes root in
                     advance two_frames;
                     let framed = classes root in
                     advance (duration + 50);
                     let after = shapes (as_node root) in
                     View.unmount mounted;
                     expect (at_once, framed, after)
                     |. to_equal (entering "t-enter-from t-enter-active", entering "t-enter-active t-enter-to", fresh next))))
            [%mel.obj { numRuns = 200 }]);
      test "in a group, a row that moves is slid from where it was, then the slide is cleared" (fun () ->
          let restore_rects = stub_rects () in
          (fun run ->
            match run () with
            | () -> restore_rects ()
            | exception error ->
                restore_rects ();
                raise error)
            (fun () ->
              check
                (property (tapes ~shortest:4 ~longest:30) (fun values ->
                     in_fake_time (fun () ->
                         let tape = tape values in
                         let start = shuffle tape (Array.to_list keys) in
                         let next = shuffle tape start in
                         let root, mounted = settled Group start in
                         View.patch mounted (wrapped Group next);
                         let index key items =
                           fst (List.find (fun (_, other) -> String.equal other key) (List.mapi (fun at key -> (at, key)) items))
                         in
                         let offset key = (index key start - index key next) * 20 in
                         let slides =
                           Array.to_list
                             (Array.map (fun element -> transform (style element)) (elements (children root)))
                         in
                         let expected_slides =
                           List.map
                             (fun key ->
                               match offset key with 0 -> "" | dy -> "translate(0px, " ^ string_of_int dy ^ "px)")
                             next
                         in
                         advance two_frames;
                         let framed = classes root in
                         let released =
                           Array.to_list
                             (Array.map (fun element -> transform (style element)) (elements (children root)))
                         in
                         advance (duration + 50);
                         let after = shapes (as_node root) in
                         View.unmount mounted;
                         expect (slides, released, framed, after)
                         |. to_equal
                              ( expected_slides,
                                List.map (fun _ -> "") next,
                                List.map (fun key -> (key, match offset key with 0 -> "" | _ -> "t-move")) next,
                                fresh next ))))
                [%mel.obj { numRuns = 200 }]));
      test "a row removed while it is still entering leaves with the leave classes only" (fun () ->
          check
            (property (tapes ~shortest:2 ~longest:20) (fun values ->
                 in_fake_time (fun () ->
                     let tape = tape values in
                     let wrapper = wrapper_of tape in
                     let start = List.filter (fun key -> not (String.equal key "f")) (subset tape) in
                     let root, mounted = settled wrapper start in
                     View.patch mounted (wrapped wrapper (start @ [ "f" ]));
                     advance (draw tape (duration + two_frames));
                     View.patch mounted (wrapped wrapper start);
                     let at_once = List.assoc "f" (classes root) in
                     advance two_frames;
                     let framed = List.assoc "f" (classes root) in
                     View.unmount mounted;
                     expect (at_once, framed)
                     |. to_equal ("t-leave-from t-leave-active", "t-leave-active t-leave-to"))))
            [%mel.obj { numRuns = 200 }]);
      test_async "without a duration, a row leaves exactly when the last of its animations finishes" (fun () ->
          check_async
            (async_property (tapes ~shortest:2 ~longest:10) (fun values ->
                 let tape = tape values in
                 let count = draw tape 4 in
                 let order = shuffle tape (List.init count Fun.id) in
                 let restore = animated count in
                 use_fake_timers [%mel.obj { toFake = [| "requestAnimationFrame" |] }];
                 let shown items = Transition.make ~name:"t" (rows items) in
                 let root = create_element document "ul" in
                 let mounted = View.mount (shown [ "a"; "b" ]) ~parent:root ~before:None in
                 View.patch mounted (shown [ "a" ]);
                 advance two_frames;
                 use_real_timers_now ();
                 let rec finish remaining seen =
                   Js.Promise.then_
                     (fun () ->
                       let seen = shown_keys root :: seen in
                       match remaining with
                       | [] -> Js.Promise.resolve (List.rev seen)
                       | index :: rest ->
                           finish_animation index;
                           finish rest seen)
                     (drained ())
                 in
                 Js.Promise.then_
                   (fun seen ->
                     View.unmount mounted;
                     restore ();
                     expect seen
                     |. to_equal (List.init count (fun _ -> [ "a"; "b" ]) @ [ [ "a" ] ]);
                     Js.Promise.resolve ())
                   (finish order [])))
            [%mel.obj { numRuns = 60 }]);
      test "unmounting the wrapper takes its leaving rows with it at once" (fun () ->
          check
            (property (tapes ~shortest:2 ~longest:20) (fun values ->
                 in_fake_time (fun () ->
                     let tape = tape values in
                     let wrapper = wrapper_of tape in
                     let start = shuffle tape (Array.to_list keys) in
                     let root, mounted = settled wrapper start in
                     View.patch mounted (wrapped wrapper (List.filter (fun _ -> draw tape 2 = 0) start));
                     advance (draw tape 60);
                     View.unmount mounted;
                     let left = child_count root in
                     advance (duration + 100);
                     expect (left, child_count root) |. to_equal (0, 0))))
            [%mel.obj { numRuns = 100 }]);
      test "without a duration, a row leaves after the longest delay plus duration its style declares" (fun () ->
          check
            (property (tapes ~shortest:4 ~longest:10) (fun values ->
                 in_fake_time (fun () ->
                     let tape = tape values in
                     let long = 50 + draw tape 250 and short = 10 + draw tape 40 and delay = draw tape 60 in
                     let written = match draw tape 2 with 0 -> string_of_int long ^ "ms" | _ -> Js.Float.toString (float_of_int long /. 1000.) ^ "s" in
                     let template =
                       Template.make
                         ~html:
                           ("<li style=\"transition-duration: " ^ string_of_int short ^ "ms, " ^ written
                          ^ "; transition-delay: " ^ string_of_int delay ^ "ms\"></li>")
                         ~holes:[| Text ([], 0) |]
                     in
                     let shown items = Transition.make ~name:"t" (rows ~template items) in
                     let root = create_element document "ul" in
                     let mounted = View.mount (shown [ "a"; "b" ]) ~parent:root ~before:None in
                     View.patch mounted (shown [ "a" ]);
                     advance (long + delay - 1);
                     let still = shown_keys root in
                     advance 50;
                     let after = shown_keys root in
                     View.unmount mounted;
                     expect (still, after) |. to_equal ([ "a"; "b" ], [ "a" ]))))
            [%mel.obj { numRuns = 100 }]))
