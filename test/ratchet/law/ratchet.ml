open Testing

external read_file : string -> string -> string = "readFileSync" [@@mel.module "node:fs"]
external write_file : string -> string -> unit = "writeFileSync" [@@mel.module "node:fs"]
external environment : string Js.Dict.t = "env" [@@mel.scope "process"]
external print : string -> unit = "log" [@@mel.scope "console"]

type comparison = Compared | Known_gap of string | Excluded of string
type outcome = Counters.t array * string
type paired = { name : string; react : outcome; melact : outcome }

(** How a counter of a run stands against the baseline. *)
type verdict =
  | Raised of { run : string; kind : string; was : int; now : int }
  | Lowered of { run : string; kind : string; was : int; now : int }
  | Unrecorded of string
  | Dropped of string
  | Unknown of { run : string; kind : string }

let comparison kind =
  match kind with
  | Counters.Attribute | Class | Style | Frame_layout | Layout_read | Rendered | Effect_ran | Evaluated | Task | Reaction
  | Kept_timer | Kept_global | Sent | Kept_node ->
      Compared
  | Moved ->
      Known_gap
        "in bench/classics/repro/logs-chunked, filtering and searching move up to 11,369 nodes a step that React leaves \
         in place: a defect, not a design"
  | Text ->
      Known_gap
        "in bench/classics/autocomplete, typing writes up to 28 more texts a step than React: a defect, not a design"
  | Timer | Frame ->
      Known_gap
        "passive effects wait for the next frame and then a timeout, as in a browser they run after the paint; React's \
         scheduler queues them as a task"
  | Microtask ->
      Known_gap
        "an update from a discrete event is flushed in a microtask, and a controlled field is put back two microtasks \
         later; React flushes its sync lane in one"
  | Listened | Unlistened ->
      Known_gap
        "an event is delegated from the document the first time a handler for it mounts, and an event that does not \
         bubble is listened to on each element that handles it, and no longer when the element goes; React listens to \
         every event once, on the root, when it is created"
  | Kept_listener ->
      Known_gap
        "the document keeps the delegated listeners after the last root unmounts; React's are on the root container \
         and go with it"
  | Forced_layout ->
      Known_gap
        "a flush renders and writes in rounds, so a layout read in a later round follows the writes of an earlier one; \
         React reads during one render phase, before its commit writes"
  | Inserted | Removed | Recorded ->
      Known_gap
        "an instance that renders nothing keeps an empty text node for its place, and a portal marks its place in its \
         target with one, inserted and taken out with it, each with its mutation record; React inserts nothing"
  | Property ->
      Known_gap
        "a controlled select's value is written when it mounts, after its options are in the document, where React \
         marks the selected option before it inserts it; and bench/classics/settings writes 104 more control states \
         than React, not yet explained"
  | Keyed ->
      Known_gap
        "a compiled loop computes the key of a changed row to see whether the rows stayed in place, and again to find \
         where it moved; React once per render"
  | Refreshed ->
      Known_gap
        "a compiled row's lets run in its projection and again in its refresh, so a row drawn again evaluates them twice; \
         React once per render"
  | Walked ->
      Known_gap
        "effects of children put off to a later round are put back in document order: by comparing positions when few, \
         by walking the subtree that holds them when many; React keeps that order in its fibers"
  | Jobs_moved -> Excluded "React keeps effects in the order of its fibers and moves no queue"
  | Created -> Excluded "templates keep a comment anchor for every child slot, where React keeps positions in fibers"
  | Viewed | Listed | Projected -> Excluded "only the Meltea and melhole runs count it"

let loaded : string -> 'build Js.Promise.t =
  [%mel.raw
    {|function (path) {
        return import(/* @vite-ignore */ process.cwd() + "/test/ratchet/classics/clock.mjs")
          .then(function () { return import(/* @vite-ignore */ process.cwd() + "/" + path); });
      }|}]

let path_of build file = "_build/default/test/ratchet/" ^ build ^ "/output/test/ratchet/" ^ build ^ "/" ^ file

let seeded seed =
  let state = ref seed in
  Array.init 160 (fun _ ->
      state := ((!state * 1103515245) + 12345) land 0x7fffffff;
      (!state lsr 16) mod 1000)

let sequenced runs =
  let ( let* ) promise next = Js.Promise.then_ next promise in
  Js.Promise.then_
    (fun done_ -> Js.Promise.resolve (List.rev done_))
    (List.fold_left
       (fun earlier run ->
         let* done_ = earlier in
         let* result = run () in
         Js.Promise.resolve (result :: done_))
       (Js.Promise.resolve []) runs)

let total (steps, _) kind = Array.fold_left (fun sum counts -> sum + Counters.count counts kind) 0 steps

let excess (melact, _) (react, _) kind =
  Array.fold_left ( + ) 0
    (Array.mapi (fun step counts -> max 0 (Counters.count counts kind - Counters.count react.(step) kind)) melact)

let exceeding melact react =
  Array.of_list
    (List.concat_map
       (fun kind ->
         match comparison kind with
         | Compared ->
             List.filter_map
               (fun step ->
                 match (Counters.count (fst melact).(step) kind, Counters.count (fst react).(step) kind) with
                 | more, fewer when more > fewer ->
                     Some
                       (Counters.name kind ^ " in step " ^ string_of_int step ^ ": Melact " ^ string_of_int more ^ " > React "
                      ^ string_of_int fewer)
                 | _, _ -> None)
               (List.init (Array.length (fst melact)) Fun.id)
         | Known_gap _ | Excluded _ -> [])
       Counters.kinds)

let unaccounted (steps, _) =
  Array.of_list
    (List.filter_map
       (fun step ->
         let counts = steps.(step) in
         let counted kinds = List.fold_left (fun sum kind -> sum + Counters.count counts kind) 0 kinds in
         match
           ( Counters.count counts Recorded,
             (2 * Counters.count counts Moved) + counted [ Inserted; Removed; Attribute; Class; Text; Style; Property ] )
         with
         | records, writes when records > writes ->
             Some
               ("step " ^ string_of_int step ^ ": " ^ string_of_int records ^ " mutation records, " ^ string_of_int writes
              ^ " counted writes")
         | _, _ -> None)
       (List.init (Array.length steps) Fun.id))

let gaps runs =
  List.filter_map
    (fun kind ->
      match comparison kind with
      | Known_gap _ -> Some (kind, List.fold_left (fun sum run -> sum + excess run.melact run.react kind) 0 runs)
      | Compared | Excluded _ -> None)
    Counters.kinds

let baseline =
  lazy
    (match read_file "test/ratchet/baseline.json" "utf8" with
    | exception _ -> []
    | text ->
        Option.fold ~none:[]
          ~some:(fun runs ->
            List.map
              (fun (run, value) ->
                ( run,
                  Option.fold ~none:[]
                    ~some:(fun counts ->
                      List.filter_map
                        (fun (kind, count) -> Option.map (fun count -> (kind, int_of_float count)) (Js.Json.decodeNumber count))
                        (Array.to_list (Js.Dict.entries counts)))
                    (Js.Json.decodeObject value) ))
              (Array.to_list (Js.Dict.entries runs)))
          (Js.Json.decodeObject (Js.Json.parseExn text)))

let difference ~react ~melact =
  let rec first at =
    match (at < String.length react, at < String.length melact) with
    | true, true when react.[at] = melact.[at] -> first (at + 1)
    | false, false -> None
    | _, _ ->
        let around text = String.sub text (max 0 (at - 60)) (min (String.length text - max 0 (at - 60)) 160) in
        Some ("the pages differ at character " ^ string_of_int at ^ ": React " ^ around react ^ " / Melact " ^ around melact)
  in
  first 0

let never_more_than_react ~gaps:row runs =
  let recorded = Option.value ~default:[] (List.assoc_opt row (Lazy.force baseline)) in
  let measured = gaps runs in
  print
    (String.concat "\n"
       (("Law A, fixed runs, React 18 / Melact where they differ:"
        :: List.map
             (fun run ->
               "  " ^ run.name ^ ": "
               ^ String.concat ", "
                   (List.filter_map
                      (fun kind ->
                        match (total run.react kind, total run.melact kind) with
                        | react_count, melact_count when react_count = melact_count -> None
                        | react_count, melact_count ->
                            Some (Counters.name kind ^ " " ^ string_of_int react_count ^ "/" ^ string_of_int melact_count))
                      Counters.kinds))
             runs)
       @ ("Law A, known gaps, Melact's total excess over React 18 in the steps of these runs:"
         :: List.map (fun (kind, sum) -> "  " ^ Counters.name kind ^ ": " ^ string_of_int sum) measured)));
  expect
    ( Array.of_list
        (List.map (fun run -> (run.name, difference ~react:(snd run.react) ~melact:(snd run.melact), exceeding run.melact run.react)) runs),
      Array.of_list
        (List.filter_map
           (fun (kind, sum) ->
             match Option.value ~default:0 (List.assoc_opt (Counters.name kind) recorded) with
             | allowed when sum > allowed ->
                 Some (Counters.name kind ^ ": Melact exceeds React by " ^ string_of_int sum ^ ", recorded " ^ string_of_int allowed)
             | _ -> None)
           measured) )
  |. to_equal (Array.of_list (List.map (fun run -> (run.name, None, [||])) runs), [||])

let never_more_than_last_time ~part ~owned rows =
  let current =
    List.map
      (fun (name, counts) ->
        (name, List.filter_map (fun (kind, count) -> match count with 0 -> None | count -> Some (Counters.name kind, count)) counts))
      rows
  in
  Option.iter
    (fun directory ->
      write_file
        (directory ^ "/" ^ part ^ ".json")
        (([%mel.raw
            {|function (entries) {
                return JSON.stringify(Object.fromEntries(entries.map(function (entry) { return [entry[0], Object.fromEntries(entry[1])]; })), null, 2) + "\n";
              }|}]
           : (string * (string * int) array) array -> string)
           (Array.of_list (List.map (fun (name, counts) -> (name, Array.of_list counts)) current))))
    (Js.Dict.get environment "RATCHET_OUT");
  let names = List.map Counters.name Counters.kinds in
  let ours =
    List.filter (fun (run, _) -> List.exists (fun prefix -> String.starts_with ~prefix run) owned) (Lazy.force baseline)
  in
  let verdicts =
    List.concat_map
      (fun (run, counts) ->
        Option.fold ~none:[ Unrecorded run ]
          ~some:(fun recorded ->
            List.filter_map
              (fun kind ->
                match (Option.value ~default:0 (List.assoc_opt kind recorded), Option.value ~default:0 (List.assoc_opt kind counts)) with
                | was, now when now > was -> Some (Raised { run; kind; was; now })
                | was, now when now < was -> Some (Lowered { run; kind; was; now })
                | _, _ -> None)
              names
            @ List.filter_map
                (fun (kind, _) ->
                  Option.fold ~none:(Some (Unknown { run; kind })) ~some:(fun _ -> None) (List.find_opt (String.equal kind) names))
                recorded)
          (List.assoc_opt run ours))
      current
    @ List.filter_map
        (fun (run, _) -> Option.fold ~none:(Some (Dropped run)) ~some:(fun _ -> None) (List.assoc_opt run current))
        ours
  in
  let shown verdict =
    match verdict with
    | Raised { run; kind; was; now } -> {js|↑ |js} ^ run ^ {js| · |js} ^ kind ^ ": " ^ string_of_int was ^ {js| → |js} ^ string_of_int now
    | Lowered { run; kind; was; now } -> {js|↓ |js} ^ run ^ {js| · |js} ^ kind ^ ": " ^ string_of_int was ^ {js| → |js} ^ string_of_int now
    | Unrecorded run -> "+ " ^ run ^ ": not in the baseline yet"
    | Dropped run -> "- " ^ run ^ ": in the baseline, no longer run"
    | Unknown { run; kind } -> "? " ^ run ^ {js| · |js} ^ kind ^ ": no such counter"
  in
  print
    (String.concat "\n"
       (("Law B, " ^ part ^ ": " ^ string_of_int (List.length current) ^ " runs, "
        ^ string_of_int (List.length current * List.length names)
        ^ " counters against test/ratchet/baseline.json")
        :: (match verdicts with
           | [] -> [ "  all equal to the baseline" ]
           | _ :: _ -> List.map (fun verdict -> "  " ^ shown verdict) verdicts)
       @ Option.to_list
           (List.find_map
              (fun verdict ->
                match verdict with
                | Lowered _ -> Some "  lower the baseline to these numbers with: node test/ratchet/lower.mjs"
                | Raised _ | Unrecorded _ | Dropped _ | Unknown _ -> None)
              verdicts)));
  expect
    (Array.of_list
       (List.filter_map
          (fun verdict ->
            match verdict with Lowered _ -> None | Raised _ | Unrecorded _ | Dropped _ | Unknown _ -> Some (shown verdict))
          verdicts))
  |. to_equal [||]
