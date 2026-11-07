open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"

let ( let* ) promise next = Js.Promise.then_ next promise
let gaps = "Law A: Melact's excess over React 18 on the big page"
let small = 200
let large = 2_000

let sized rows =
  let* react = Big_page.run React rows in
  let* melact = Big_page.run Melact rows in
  Js.Promise.resolve (rows, react, melact)

let both =
  lazy
    (let* small_runs = sized small in
     let* large_runs = sized large in
     Js.Promise.resolve (small_runs, large_runs))

let runs =
  lazy
    (let* small_runs, large_runs = Lazy.force both in
     Js.Promise.resolve [ small_runs; large_runs ])

let () =
  describe "A small change costs the same on a big page" (fun () ->
      test_long
        ("every step after the mount counts exactly as much on " ^ string_of_int large ^ " rows as on "
       ^ string_of_int small ^ ", under React 18 and under Melact, and the large page has more than 20,000 elements")
        (fun () ->
          let* (_, small_react, small_melact), (_, large_react, large_melact) = Lazy.force both in
          let differences side (small_run : Classics.run) (large_run : Classics.run) =
            let small_steps = fst small_run##outcome and large_steps = fst large_run##outcome in
            List.concat_map
              (fun step ->
                List.filter_map
                  (fun kind ->
                    match (Counters.count small_steps.(step) kind, Counters.count large_steps.(step) kind) with
                    | few, many when few <> many ->
                        Some
                          (side ^ ", " ^ (small_run##names).(step) ^ ", " ^ Counters.name kind ^ ": " ^ string_of_int few ^ " on "
                         ^ string_of_int small ^ " rows, " ^ string_of_int many ^ " on " ^ string_of_int large)
                    | _, _ -> None)
                  Counters.kinds)
              (List.init (Array.length small_steps - 3) (fun step -> step + 1))
          in
          expect
            ( large_melact##elements > 20_000,
              differences "React" small_react large_react @ differences "Melact" small_melact large_melact )
          |. to_equal (true, []);
          Js.Promise.resolve ())
        600_000);
  describe "Law A: never more than React" (fun () ->
      test_long
        "on the big page, Melact does no more of any compared kind than React 18 in any step and shows the same page, \
         every mutation record is a counted write, and the known gaps do not grow"
        (fun () ->
          let* runs = Lazy.force runs in
          let paired =
            List.map
              (fun (rows, (react : Classics.run), (melact : Classics.run)) ->
                { Ratchet.name = "the big page, " ^ string_of_int rows ^ " rows"; react = react##outcome; melact = melact##outcome })
              runs
          in
          expect
            ( List.concat_map (fun (_, (react : Classics.run), (melact : Classics.run)) -> Array.to_list react##failures @ Array.to_list melact##failures) runs,
              List.map (fun (run : Ratchet.paired) -> (Ratchet.unaccounted run.react, Ratchet.unaccounted run.melact)) paired )
          |. to_equal ([], List.map (fun _ -> ([||], [||])) paired);
          Ratchet.never_more_than_react ~gaps paired;
          Js.Promise.resolve ())
        600_000);
  describe "Law B: never more than last time" (fun () ->
      test_long "no counter of the big page under Melact is above the checked-in baseline" (fun () ->
          let* runs = Lazy.force runs in
          Ratchet.never_more_than_last_time ~part:"bigpage" ~owned:[ "big page: "; gaps ]
            (List.map
               (fun (rows, _, (melact : Classics.run)) ->
                 ( "big page: " ^ string_of_int rows ^ " rows, Melact",
                   List.map (fun kind -> (kind, Ratchet.total melact##outcome kind)) Counters.kinds ))
               runs
            @ [
                ( gaps,
                  Ratchet.gaps
                    (List.map
                       (fun (rows, (react : Classics.run), (melact : Classics.run)) ->
                         { Ratchet.name = string_of_int rows; react = react##outcome; melact = melact##outcome })
                       runs) );
              ]);
          Js.Promise.resolve ())
        600_000)
