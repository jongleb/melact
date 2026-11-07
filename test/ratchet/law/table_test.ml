open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"

(** A build of the event table of bench/classics, run through its scenario. *)
type table = < run : (unit -> Ratchet.outcome Js.Promise.t[@mel.meth]) > Js.t

let gaps = "Law A: Melact's excess over React 18 on the event table"
let ( let* ) promise next = Js.Promise.then_ next promise

let paired =
  lazy
    (let* (react : table) = Ratchet.loaded (Ratchet.path_of "eventtable/react" "table.mjs") in
     let* (melact : table) = Ratchet.loaded (Ratchet.path_of "eventtable/melact" "table.mjs") in
     let* react_outcome = react##run () in
     let* melact_outcome = melact##run () in
     Js.Promise.resolve
       { Ratchet.name = "the event table of bench/classics, through its scenario"; react = react_outcome; melact = melact_outcome })

let () =
  describe "Law A: never more than React" (fun () ->
      test_long
        "on the event table, Melact does no more of any compared kind than React 18 in any step and shows the same \
         page, and the known gaps do not grow"
        (fun () ->
          let* run = Lazy.force paired in
          Ratchet.never_more_than_react ~gaps [ run ];
          Js.Promise.resolve ())
        300_000);
  describe "Law B: never more than last time" (fun () ->
      test_long "no counter of the event table is above the checked-in baseline" (fun () ->
          let* run = Lazy.force paired in
          Ratchet.never_more_than_last_time ~part:"table" ~owned:[ "event table: "; gaps ]
            [
              ("event table: Melact, through its scenario", List.map (fun kind -> (kind, Ratchet.total run.melact kind)) Counters.kinds);
              (gaps, Ratchet.gaps [ run ]);
            ];
          Js.Promise.resolve ())
        300_000)
