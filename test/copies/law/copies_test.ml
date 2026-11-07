open Testing

external test_async : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"

external start_other : Dom.element -> unit = "start"
[@@mel.module "../../../../../widget/output/test/copies/widget/counter.mjs"]

external bubbling : string -> < bubbles : bool > Js.t -> Dom.event = "Event" [@@mel.new]
external set_value : Dom.element -> string -> unit = "value" [@@mel.set]
external remove : Dom.element -> unit = "remove" [@@mel.send]

let settled : unit -> unit Js.Promise.t = [%mel.raw {|function () { return new Promise((resolve) => setTimeout(resolve, 0)); }|}]
let ( let* ) promise next = Js.Promise.then_ next promise

(** Where the second copy's widget sits: beside the first, or inside it. *)
type placement = Beside | Inside

(** One input on the page. *)
type step = Press of int | Type of int * string

let () =
  describe "Two copies of melhole on one page" (fun () ->
      test_async "each delivers every event to its own handlers exactly once, beside each other or nested" (fun () ->
          check_async
            (async_property (tapes ~shortest:2 ~longest:40) (fun values ->
                 let tape = tape values in
                 let placement = match draw tape 2 with 0 -> Beside | _ -> Inside in
                 let first = attached () in
                 Counter.start first;
                 let* () = settled () in
                 let second = create_element document "div" in
                 (match placement with
                 | Beside -> append_child (body document) second
                 | Inside -> append_child (select first ".widget") second);
                 start_other second;
                 let* () = settled () in
                 let roots = [| first; second |] in
                 let steps =
                   List.init (1 + draw tape 12) (fun index ->
                       match draw tape 2 with 0 -> Press (draw tape 2) | _ -> Type (draw tape 2, "t" ^ string_of_int index))
                 in
                 let presses = [| 0; 0 |] and typed = [| ""; "" |] in
                 let rec run steps =
                   match steps with
                   | [] -> Js.Promise.resolve ()
                   | step :: rest ->
                       (match step with
                       | Press at ->
                           click (select roots.(at) ":scope > .widget > .press");
                           presses.(at) <- presses.(at) + 1
                       | Type (at, text) ->
                           let field = select roots.(at) ":scope > .widget > .field" in
                           set_value field text;
                           dispatch field (bubbling "input" [%mel.obj { bubbles = true }]);
                           typed.(at) <- text);
                       let* () = settled () in
                       run rest
                 in
                 let* () = run steps in
                 let shown at =
                   ( text_content (select roots.(at) ":scope > .widget > .press"),
                     text_content (select roots.(at) ":scope > .widget > .typed") )
                 in
                 let seen = (shown 0, shown 1) in
                 remove second;
                 remove first;
                 expect seen
                 |. to_equal ((string_of_int presses.(0), typed.(0)), (string_of_int presses.(1), typed.(1)));
                 Js.Promise.resolve ()))
            [%mel.obj { numRuns = 100 }])
        60000)
