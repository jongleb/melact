open Testing

external test_async : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"
external set_inner_html : Dom.element -> string -> unit = "innerHTML" [@@mel.set]
external set_id : Dom.element -> string -> unit = "id" [@@mel.set]
external select_all : Dom.element -> string -> Dom.nodeList = "querySelectorAll" [@@mel.send]
external elements : Dom.nodeList -> Dom.element array = "from" [@@mel.scope "Array"]
external remove : Dom.element -> unit = "remove" [@@mel.send]
external contains : Dom.element -> Dom.element -> bool = "contains" [@@mel.send]

(** The client a page starts: the one that mounts on an empty root, or the one that resumes the built page. *)
type client = Mounted | Resumed

(** What the user does: a button pressed, by its id, or a row's label or remove icon clicked, by the row's index. *)
type step = Press of string | Choose of int | Drop of int

(** What a resumed page did before and at its first input. *)
type waking = {
  untouched : int * int;  (** Views run and DOM mutations between the code's arrival and the first input. *)
  kept : int;  (** Elements the build sent still on the page after the first input. *)
  created : int;  (** Elements on the page after the first input that the build did not send. *)
  sent : int;  (** Elements the build sent. *)
}

let laws ~framework ~page ~renders ~import =
  let later : int -> unit Js.Promise.t =
    [%mel.raw {|function (delay) { return new Promise((resolve) => setTimeout(resolve, delay)); }|}]
  in
  let install : string -> unit = [%mel.raw {|function (script) { (0, eval)(script); }|}] in
  let shipped : string -> string * string array =
    [%mel.raw
      {|function (page) {
    const parsed = new DOMParser().parseFromString(page, "text/html");
    return [parsed.getElementById("main").innerHTML, Array.from(parsed.head.querySelectorAll("script:not([src])"), (script) => script.textContent)];
  }|}]
  in
  let seeded : int -> unit =
    [%mel.raw
      {|function (seed) {
    let state = ((seed + 1) * 2654435761) >>> 0 || 1;
    Math.random = function () {
      state ^= state << 13; state >>>= 0; state ^= state >>> 17; state ^= state << 5; state >>>= 0;
      return state / 4294967296;
    };
  }|}]
  in
  let ( let* ) promise next = Js.Promise.then_ next promise in
  let buttons = [| "run"; "add"; "update"; "clear"; "swaprows" |] in
  let runs = ref 0 in
  let started client seed =
    incr runs;
    seeded seed;
    import ((match client with Mounted -> "mounted" | Resumed -> "resumed") ^ ".mjs?run=" ^ string_of_int !runs)
  in
  let fresh () =
    let root = attached () in
    set_id root "main";
    root
  in
  let perform root step =
    let row index =
      let rows = elements (select_all root "tbody tr") in
      match Array.length rows with 0 -> None | count -> Some rows.(index mod count)
    in
    match step with
    | Press id -> click (select root ("#" ^ id))
    | Choose index -> Option.iter (fun row -> click (select row "td:nth-child(2) a")) (row index)
    | Drop index -> Option.iter (fun row -> click (select row "td:nth-child(3) a")) (row index)
  in
  let observe root = shapes (as_node root) in
  let count root = Array.length (elements (select_all root "*")) in
  let rec watch root remaining seen =
    match remaining with
    | [] -> Js.Promise.resolve (List.rev seen)
    | step :: rest ->
        perform root step;
        let* () = later 0 in
        watch root rest (observe root :: seen)
  in
  let split late = match late with [] -> ([], []) | step :: rest -> ([ step ], rest) in
  let mounted seed early late =
    let root = fresh () in
    let* () = started Mounted seed in
    let* () = later 0 in
    let* _ = watch root early [] in
    let arrived = observe root in
    let before = count root in
    let first, rest = split late in
    let* after_first = watch root first [] in
    let grown = count root - before in
    let* seen = watch root rest [] in
    remove root;
    Js.Promise.resolve ((arrived :: after_first) @ seen, grown)
  in
  let resumed seed early late =
    let root = fresh () in
    let html, scripts = shipped page in
    set_inner_html root html;
    Array.iter install scripts;
    let sent = elements (select_all root "*") in
    List.iter (perform root) early;
    let mutated = ref 0 in
    let changes = observer (fun () -> incr mutated) in
    Testing.observe changes root [%mel.obj { childList = true; subtree = true; attributes = true; characterData = true }];
    renders := 0;
    let* () = started Resumed seed in
    let* () = later 0 in
    let untouched = (!renders, !mutated + Array.length (take_records changes)) in
    disconnect changes;
    let arrived = observe root in
    let first, rest = split late in
    let* after_first = watch root first [] in
    let present = elements (select_all root "*") in
    let kept = Array.length (Js.Array.filter ~f:(fun element -> contains root element) sent) in
    let created =
      Array.length (Js.Array.filter ~f:(fun element -> not (Array.exists (fun other -> same element other) sent)) present)
    in
    let* seen = watch root rest [] in
    remove root;
    Js.Promise.resolve ((arrived :: after_first) @ seen, { untouched; kept; created; sent = Array.length sent })
  in
  let scenario values =
    let tape = tape values in
    let seed = draw tape 1000 in
    let early = List.init (draw tape 3) (fun _ -> Press buttons.(draw tape (Array.length buttons))) in
    let late =
      List.init (draw tape 6) (fun _ ->
          match draw tape 4 with
          | 0 -> Choose (draw tape 1000)
          | 1 -> Drop (draw tape 1000)
          | _ -> Press buttons.(draw tape (Array.length buttons)))
    in
    (seed, early, late)
  in
  describe (framework ^ ": a page built at build time, resumed") (fun () ->
      test_async
        "shows, after any inputs before and after its code arrives, exactly what a page mounted by the client shows"
        (fun () ->
          check_async
            (async_property (tapes ~shortest:6 ~longest:30) (fun values ->
                 let seed, early, late = scenario values in
                 let* shown, _ = resumed seed early late in
                 let* expected, _ = mounted seed early late in
                 expect shown |. to_equal expected;
                 Js.Promise.resolve ()))
            [%mel.obj { numRuns = 40 }])
        120000;
      test_async "keeps at its first input every element the build sent, and creates only what that input creates on a mounted page"
        (fun () ->
          check_async
            (async_property (tapes ~shortest:6 ~longest:30) (fun values ->
                 let seed, _, late = scenario values in
                 let late = match late with Press _ :: _ -> late | _ -> Press buttons.(seed mod Array.length buttons) :: late in
                 let* _, waking = resumed seed [] late in
                 let* _, grown = mounted seed [] late in
                 expect (waking.kept, waking.created) |. to_equal (waking.sent, grown);
                 Js.Promise.resolve ()))
            [%mel.obj { numRuns = 30 }])
        120000;
      test_async "runs no view and changes nothing until its first input" (fun () ->
          check_async
            (async_property (tapes ~shortest:6 ~longest:30) (fun values ->
                 let seed, _, late = scenario values in
                 let* _, waking = resumed seed [] late in
                 expect waking.untouched |. to_equal (0, 0);
                 Js.Promise.resolve ()))
            [%mel.obj { numRuns = 30 }])
        120000)
