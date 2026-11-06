open Testing

external test_async : string -> (unit -> unit Js.Promise.t) -> unit = "test"

external keyboard : string -> < key : string ; bubbles : bool > Js.t -> Dom.event = "KeyboardEvent"
[@@mel.new]

external bubbling : string -> < bubbles : bool > Js.t -> Dom.event = "Event" [@@mel.new]
external set_value : Dom.element -> string -> unit = "value" [@@mel.set]
external value_of : Dom.element -> string = "value" [@@mel.get]
external checked_of : Dom.element -> bool = "checked" [@@mel.get]
external set_inner_html : Dom.element -> string -> unit = "innerHTML" [@@mel.set]
external select_all : Dom.element -> string -> Dom.nodeList = "querySelectorAll" [@@mel.send]
external elements : Dom.nodeList -> Dom.element array = "from" [@@mel.scope "Array"]
external remove : Dom.element -> unit = "remove" [@@mel.send]

let go_to : string -> unit =
  [%mel.raw
    {|function (hash) { history.replaceState(null, "", hash); window.dispatchEvent(new Event("hashchange")); }|}]

let later : int -> unit Js.Promise.t =
  [%mel.raw {|function (delay) { return new Promise((resolve) => setTimeout(resolve, delay)); }|}]

let install : string -> unit = [%mel.raw {|function (script) { (0, eval)(script); }|}]
let ( let* ) promise next = Js.Promise.then_ next promise

(** What happens on the page: an input, or a new route once the code is there. *)
type step = Press_first | Press_second | Type of string | Tick | Key of string | Route of string

(** What a resumed page did before and at its first input or message. *)
type waking = {
  untouched : int * int;  (** View runs and DOM mutations between the code's arrival and the first input. *)
  taking : int * int * int;
      (** View runs, server elements kept and elements created: right after an input, after the draw of a message. *)
  sent : int;  (** Elements the server sent. *)
}

let words = [| "a"; "tea"; ""; "<b> & c" |]
let keys = [| "Enter"; "x"; "Escape" |]
let hashes = [| "#/one"; "#/two"; "#/" |]

let perform root step =
  match step with
  | Press_first -> click (select root ".first")
  | Press_second -> click (select root ".second")
  | Type text ->
      let field = select root ".field" in
      set_value field text;
      dispatch field (bubbling "input" [%mel.obj { bubbles = true }])
  | Tick -> click (select root ".tick")
  | Key key -> dispatch (select root ".field") (keyboard "keydown" [%mel.obj { key; bubbles = true }])
  | Route hash -> go_to hash

let observe root =
  ( shapes (as_node root),
    List.map (fun field -> (value_of field, checked_of field)) (Array.to_list (elements (select_all root "input"))) )

let rec watch root remaining seen =
  match remaining with
  | [] -> Js.Promise.resolve (List.rev seen)
  | step :: rest ->
      perform root step;
      let* () = later 0 in
      watch root rest (observe root :: seen)

let mounted model early late =
  go_to "#/";
  let root = attached () in
  let program =
    Program.element ~init:(model, Cmd.none) ~update:Journal.update ~view:Journal.view
      ~subscriptions:Journal.subscriptions root
  in
  let* _ = watch root early [] in
  let arrived = observe root in
  let* seen = watch root late [] in
  Program.stop program;
  remove root;
  Js.Promise.resolve (arrived :: seen)

let served start model early late =
  go_to "#/";
  let root = attached () in
  let calls = ref 0 in
  set_inner_html root (Program.render ~view:Journal.view model);
  let sent = elements (select_all root "*") in
  install Melhole_server.capture;
  let* _ = watch root early [] in
  let mutated = ref 0 in
  let changes = observer (fun () -> incr mutated) in
  Testing.observe changes root [%mel.obj { childList = true; subtree = true; attributes = true; characterData = true }];
  let program =
    Program.element ~start ~init:(model, Cmd.none) ~update:Journal.update
      ~view:(fun model ->
        incr calls;
        Journal.view model)
      ~subscriptions:Journal.subscriptions root
  in
  let* () = later 0 in
  let untouched = (!calls, !mutated + Array.length (take_records changes)) in
  disconnect changes;
  let arrived = observe root in
  let first, rest = match late with [] -> ([], []) | step :: rest -> ([ step ], rest) in
  calls := 0;
  List.iter (perform root) first;
  let taken () =
    let present = elements (select_all root "*") in
    ( !calls,
      Array.length (Js.Array.filter ~f:(fun node -> Array.exists (fun other -> same node other) present) sent),
      Array.length (Js.Array.filter ~f:(fun node -> not (Array.exists (fun other -> same node other) sent)) present) )
  in
  let* taking =
    match first with
    | [ Route _ ] ->
        let* () = later 0 in
        Js.Promise.resolve (taken ())
    | _ -> Js.Promise.resolve (taken ())
  in
  let* () = later 0 in
  let after_first = List.map (fun _ -> observe root) first in
  let* seen = watch root rest [] in
  Program.stop program;
  remove root;
  Js.Promise.resolve (arrived :: (after_first @ seen), { untouched; taking; sent = Array.length sent })

let user tape ~answering =
  match (draw tape 5, answering) with
  | 0, `Answering -> Press_first
  | (0 | 1), _ -> Press_second
  | 2, _ -> Type words.(draw tape (Array.length words))
  | 3, _ -> Tick
  | _, _ -> Key keys.(draw tape (Array.length keys))

let scenario values =
  let tape = tape values in
  let model =
    {
      Journal.entries = List.init (draw tape 3) (fun index -> Journal.Pressed index);
      field = words.(draw tape (Array.length words));
      ticked = (match draw tape 2 with 0 -> false | _ -> true);
    }
  in
  let early =
    match draw tape 2 with 0 -> [] | _ -> List.init (draw tape 4) (fun _ -> user tape ~answering:`Silent)
  in
  let late =
    List.init (draw tape 6) (fun _ ->
        match draw tape 5 with 0 -> Route hashes.(draw tape (Array.length hashes)) | _ -> user tape ~answering:`Answering)
  in
  (model, early, late)

let () =
  describe "Resuming a server's page" (fun () ->
      test_async "a resumed page shows what an eagerly hydrated page and a mounted page show, after any inputs before and after the code arrives" (fun () ->
          check_async
            (async_property (tapes ~shortest:8 ~longest:40) (fun values ->
                 let model, early, late = scenario values in
                 let* resumed, _ = served Program.resume model early late in
                 let* hydrated, _ = served Program.hydrate model early late in
                 let* mounted = mounted model early late in
                 expect (resumed = hydrated, resumed = mounted) |. to_equal (true, true);
                 Js.Promise.resolve ()))
            [%mel.obj { numRuns = 150 }]);
      test_async "with no input before the code arrives, a resumed page runs no view and changes nothing until its first input or message" (fun () ->
          check_async
            (async_property (tapes ~shortest:8 ~longest:40) (fun values ->
                 let model, _, late = scenario values in
                 let* _, waking = served Program.resume model [] late in
                 expect waking.untouched |. to_equal (0, 0);
                 Js.Promise.resolve ()))
            [%mel.obj { numRuns = 60 }]);
      test_async "its first input takes the page over once, keeping every element the server sent and creating none; a message takes it over at its draw" (fun () ->
          check_async
            (async_property (tapes ~shortest:8 ~longest:40) (fun values ->
                 let model, _, late = scenario values in
                 let late = match late with [] -> [ Press_second ] | _ :: _ -> late in
                 let* _, waking = served Program.resume model [] late in
                 expect waking.taking
                 |. to_equal (match late with Route _ :: _ -> (2, waking.sent, 1) | _ -> (1, waking.sent, 0));
                 Js.Promise.resolve ()))
            [%mel.obj { numRuns = 60 }]))
