open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"

(** A build that renders the page of bench/ssr to HTML. *)
type rendered = < html : (int -> string[@mel.meth]) > Js.t

(** A build that hydrates the page of bench/ssr from HTML. *)
type hydrated = < start : (string -> int -> unit[@mel.meth]) > Js.t

let ( let* ) promise next = Js.Promise.then_ next promise
let gaps = "Law A: Melact's excess over React 18 hydrating bench/ssr's page"
let built side file rows = "_build/default/test/ratchet/served/" ^ side ^ "/output/test/ratchet/served/" ^ side ^ "/" ^ file ^ "?rows=" ^ string_of_int rows

let sized rows =
  let* (server : rendered) = Ratchet.loaded (built "server" "rendered.mjs" rows) in
  let* (react_server : rendered) = Ratchet.loaded (built "react" "rendered.mjs" rows) in
  let* steps = Classics.scenario "test/ratchet/served/scenario.mjs" in
  let melact_html = server##html rows and react_html = react_server##html rows in
  let hydrating side html =
    Classics.driven ~build:(built side "hydrated.mjs" rows) ~start:(fun (page : hydrated) -> page##start html rows) steps
  in
  let* react = hydrating "react" react_html in
  let* melact = hydrating "melact" melact_html in
  Js.Promise.resolve (rows, (String.length react_html, String.length melact_html), react, melact)

let runs = lazy (Ratchet.sequenced (List.map (fun rows () -> sized rows) [ 10; 100; 1_000 ]))

let hydration = "Law A: Melact's excess over React 18 in the hydration itself, bench/ssr's page"

let paired runs =
  let after (steps, page) = (Array.sub steps 1 (Array.length steps - 1), page) in
  List.map
    (fun (rows, _, (react : Classics.run), (melact : Classics.run)) ->
      {
        Ratchet.name = "bench/ssr's page, " ^ string_of_int rows ^ " rows, after its hydration";
        react = after react##outcome;
        melact = after melact##outcome;
      })
    runs

let hydrating_excess runs =
  List.map
    (fun kind ->
      ( kind,
        List.fold_left
          (fun sum (_, _, (react : Classics.run), (melact : Classics.run)) ->
            sum + max 0 (Counters.count (fst melact##outcome).(0) kind - Counters.count (fst react##outcome).(0) kind))
          0 runs ))
    Counters.kinds

let () =
  describe "Law A: never more than React" (fun () ->
      test_long
        "Melact's server writes no more bytes than React 18's renderToString, and once hydrated the page does no more of \
         any compared kind than React 18's, and the known gaps do not grow"
        (fun () ->
          let* runs = Lazy.force runs in
          expect
            ( List.filter_map
                (fun run ->
                  match run with
                  | rows, (react_bytes, melact_bytes), _, _ when melact_bytes > react_bytes ->
                      Some (string_of_int rows ^ " rows: Melact " ^ string_of_int melact_bytes ^ " bytes > React " ^ string_of_int react_bytes)
                  | _, _, _, _ -> None)
                runs,
              List.concat_map
                (fun (_, _, (react : Classics.run), (melact : Classics.run)) -> Array.to_list react##failures @ Array.to_list melact##failures)
                runs,
              List.map (fun (run : Ratchet.paired) -> (Ratchet.unaccounted run.react, Ratchet.unaccounted run.melact)) (paired runs) )
          |. to_equal ([], [], List.map (fun _ -> ([||], [||])) runs);
          Ratchet.never_more_than_react ~gaps (paired runs);
          Js.Promise.resolve ())
        300_000);
  describe "Law B: never more than last time" (fun () ->
      test_long
        "no byte count of Melact's server, no counter of hydrating it, and no excess of its hydration over React 18's is \
         above the checked-in baseline" (fun () ->
          let* runs = Lazy.force runs in
          Ratchet.never_more_than_last_time ~part:"served" ~owned:[ "served: "; gaps; hydration ]
            (List.concat_map
               (fun (rows, (_, melact_bytes), _, (melact : Classics.run)) ->
                 [
                   ("served: bench/ssr's page, " ^ string_of_int rows ^ " rows, Melact's HTML", [ (Counters.Sent, melact_bytes) ]);
                   ( "served: bench/ssr's page, " ^ string_of_int rows ^ " rows, hydrated by Melact",
                     List.map (fun kind -> (kind, Ratchet.total melact##outcome kind)) Counters.kinds );
                 ])
               runs
            @ [ (gaps, Ratchet.gaps (paired runs)); (hydration, hydrating_excess runs) ]);
          Js.Promise.resolve ())
        300_000)
