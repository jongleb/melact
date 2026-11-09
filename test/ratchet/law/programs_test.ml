open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"
external print : string -> unit = "log" [@@mel.scope "console"]
external check_seeded : property -> < numRuns : int ; seed : int > Js.t -> unit Js.Promise.t = "assert"
[@@mel.module "fast-check"]
external environment : string Js.Dict.t = "env" [@@mel.scope "process"]

(** A build of the generated React programs. *)
type dual =
  < random : (int array -> Ratchet.outcome Js.Promise.t[@mel.meth])
  ; named : (int -> Ratchet.outcome Js.Promise.t[@mel.meth])
  ; described : (int array -> string[@mel.meth])
  ; names : string array >
  Js.t

(** Whether Law B records a fixed program as well as Law A. *)
type recording = Recorded | Compared_only

let gaps = "Law A: Melact's excess over React 18 on the generated programs"
let ( let* ) promise next = Js.Promise.then_ next promise
let builds =
  lazy
    (let* react = Ratchet.loaded (Ratchet.path_of "react" "programs.mjs") in
     let* melact = Ratchet.loaded (Ratchet.path_of "melact" "programs.mjs") in
     Js.Promise.resolve ((react : dual), (melact : dual)))

let fixed =
  lazy
    (let* react, melact = Lazy.force builds in
     let paired name recording run () =
       let* react_outcome = run react in
       let* melact_outcome = run melact in
       Js.Promise.resolve (recording, { Ratchet.name; react = react_outcome; melact = melact_outcome })
     in
     Ratchet.sequenced
       (Array.to_list (Array.mapi (fun index name -> paired name Recorded (fun (build : dual) -> build##named index)) melact##names)
       @ List.concat_map
           (fun (recording, first, count) ->
             List.init count (fun index ->
                 let seed = first + index in
                 paired ("random program, seed " ^ string_of_int seed) recording (fun (build : dual) ->
                     build##random (Ratchet.seeded seed))))
           [ (Recorded, 1, 12); (Compared_only, 13, 48) ]))

let () =
  describe "Law A: never more than React" (fun () ->
      test_long "on random programs, Melact does no more work of any compared kind than React 18, and shows the same page"
        (fun () ->
          let* react, melact = Lazy.force builds in
          let totals = Hashtbl.create 32 and exceeded = Hashtbl.create 32 in
          let* () =
            (fun property ->
              match Option.bind (Js.Dict.get environment "RATCHET_SEED") int_of_string_opt with
              | Some seed -> check_seeded property [%mel.obj { numRuns = 300; seed }]
              | None -> check_async property [%mel.obj { numRuns = 300 }])
              (async_property (tapes ~shortest:20 ~longest:160) (fun values ->
                   let* react_outcome = react##random values in
                   let* melact_outcome = melact##random values in
                   List.iter
                     (fun kind ->
                       let react_total, melact_total = Option.value ~default:(0, 0) (Hashtbl.find_opt totals kind) in
                       Hashtbl.replace totals kind
                         (react_total + Ratchet.total react_outcome kind, melact_total + Ratchet.total melact_outcome kind);
                       match Ratchet.excess melact_outcome react_outcome kind with
                       | 0 -> ()
                       | _ -> Hashtbl.replace exceeded kind (1 + Option.value ~default:0 (Hashtbl.find_opt exceeded kind)))
                     Counters.kinds;
                   expect (melact##described values, snd melact_outcome, Ratchet.exceeding melact_outcome react_outcome)
                   |. to_equal (melact##described values, snd react_outcome, [||]);
                   Js.Promise.resolve ()))
          in
          print
            (String.concat "\n"
               ("Law A, 300 random programs, totals React 18 / Melact, and in how many programs Melact did more:"
               :: List.filter_map
                    (fun kind ->
                      Option.map
                        (fun (react_total, melact_total) ->
                          "  " ^ Counters.name kind ^ ": " ^ string_of_int react_total ^ " / " ^ string_of_int melact_total
                          ^ Option.fold ~none:"" ~some:(fun count -> ", more in " ^ string_of_int count) (Hashtbl.find_opt exceeded kind)
                          ^
                          match Ratchet.comparison kind with
                          | Compared -> ""
                          | Known_gap why -> " (known gap: " ^ why ^ ")"
                          | Excluded why -> " (excluded: " ^ why ^ ")")
                        (Hashtbl.find_opt totals kind))
                    Counters.kinds));
          Js.Promise.resolve ())
        300_000;
      test_long
        "on the fixed programs, Melact does no more of any compared kind than React 18 and shows the same page, and the \
         known gaps do not grow"
        (fun () ->
          let* runs = Lazy.force fixed in
          Ratchet.never_more_than_react ~gaps (List.map snd runs);
          Js.Promise.resolve ())
        300_000);
  describe "Law B: never more than last time" (fun () ->
      test_long "no counter of a fixed Melact program or melhole loop is above the checked-in baseline" (fun () ->
          let* runs = Lazy.force fixed in
          Ratchet.never_more_than_last_time ~part:"programs" ~owned:[ "melact: "; "melhole: "; gaps ]
            (List.filter_map
               (fun (recording, (run : Ratchet.paired)) ->
                 match recording with
                 | Recorded ->
                     Some ("melact: " ^ run.name, List.map (fun kind -> (kind, Ratchet.total run.melact kind)) Counters.kinds)
                 | Compared_only -> None)
               runs
            @ Array.to_list
                (Array.map
                   (fun (name, run) ->
                     let counts = run () in
                     ("melhole: " ^ name, List.map (fun kind -> (kind, Counters.count counts kind)) Counters.kinds))
                   Loops.scenarios)
            @ [ (gaps, Ratchet.gaps (List.map snd runs)) ]);
          Js.Promise.resolve ())
        300_000)
