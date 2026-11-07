open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"
external test_skipped : string -> (unit -> unit) -> unit = "skip" [@@mel.scope "test"]
external environment : string Js.Dict.t = "env" [@@mel.scope "process"]

type step = < name : string > Js.t
type run = < outcome : Ratchet.outcome ; names : string array ; failures : string array ; elements : int > Js.t
type pace = Quick | Slow
type app = { path : string; skipped : (string * string) list }

(** The driver module of test/ratchet/classics. *)
type driver

(** A page for the driver: how to load its build, what to call once it is loaded, its steps. *)
type 'build page = < load : unit -> 'build Js.Promise.t ; start : 'build -> unit ; steps : step array > Js.t

external run_page : driver -> 'build page -> run Js.Promise.t = "run" [@@mel.send]
external scenario_of : driver -> string -> step array Js.Promise.t = "scenario" [@@mel.send]

let ( let* ) promise next = Js.Promise.then_ next promise
let driver : driver Js.Promise.t Lazy.t = lazy (Ratchet.loaded "test/ratchet/classics/driver.mjs")

let scenario path =
  let* driver = Lazy.force driver in
  scenario_of driver path

let driven ~build ~start steps =
  let* driver = Lazy.force driver in
  run_page driver [%mel.obj { load = (fun () -> Ratchet.loaded build); start; steps }]

let laws ~part ~pace apps =
  let gaps = "Law A: Melact's excess over React 18 on bench/classics, " ^ part in
  let built app framework =
    "_build/default/bench/classics/" ^ app.path ^ "/" ^ framework ^ "/output/bench/classics/" ^ app.path ^ "/" ^ framework
    ^ "/app.mjs"
  in
  let paired app () =
    let* steps = scenario ("bench/classics/" ^ app.path ^ "/scenario.mjs") in
    let kept = Js.Array.filter ~f:(fun step -> not (List.mem_assoc step##name app.skipped)) steps in
    let* react = driven ~build:(built app "react") ~start:ignore kept in
    let* melact = driven ~build:(built app "melact") ~start:ignore kept in
    Js.Promise.resolve
      ( { Ratchet.name = app.path ^ ", through its scenario"; react = react##outcome; melact = melact##outcome },
        Array.append (Array.map (fun failure -> "React: " ^ failure) react##failures)
          (Array.map (fun failure -> "Melact: " ^ failure) melact##failures) )
  in
  let runs = lazy (Ratchet.sequenced (List.map paired apps)) in
  let laws () =
    describe ("Law A: never more than React, bench/classics " ^ part) (fun () ->
        test_long
          ("on " ^ String.concat ", " (List.map (fun app -> app.path) apps)
         ^ ", Melact does no more of any compared kind than React 18 in any step and shows the same page, every mutation \
            record is a counted write, no step fails, and the known gaps do not grow")
          (fun () ->
            let* runs = Lazy.force runs in
            let paired = List.map fst runs in
            expect
              ( List.map
                  (fun (run : Ratchet.paired) -> (run.name, Ratchet.unaccounted run.react, Ratchet.unaccounted run.melact))
                  paired,
                List.concat_map (fun (_, failures) -> Array.to_list failures) runs )
            |. to_equal (List.map (fun (run : Ratchet.paired) -> (run.name, [||], [||])) paired, []);
            Ratchet.never_more_than_react ~gaps paired;
            Js.Promise.resolve ())
          600_000);
    describe ("Law B: never more than last time, bench/classics " ^ part) (fun () ->
        test_long "no counter of these apps under Melact is above the checked-in baseline" (fun () ->
            let* runs = Lazy.force runs in
            let paired = List.map fst runs in
            Ratchet.never_more_than_last_time ~part:("classics " ^ part)
              ~owned:(gaps :: List.map (fun app -> "classics: " ^ app.path ^ ", ") apps)
              (List.map2
                 (fun app (run : Ratchet.paired) ->
                   ("classics: " ^ app.path ^ ", Melact", List.map (fun kind -> (kind, Ratchet.total run.melact kind)) Counters.kinds))
                 apps paired
              @ [ (gaps, Ratchet.gaps paired) ]);
            Js.Promise.resolve ())
          600_000)
  in
  match (pace, Js.Dict.get environment "RATCHET_SLOW") with
  | Quick, _ | Slow, Some _ -> laws ()
  | Slow, None ->
      test_skipped ("bench/classics " ^ part ^ " runs only with RATCHET_SLOW set, as CI sets it") (fun () -> ())
