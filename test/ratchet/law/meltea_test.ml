open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"

(** The build of the generated Meltea programs. *)
type elm =
  < random : (int array -> Counters.t[@mel.meth]) ; named : (int -> Counters.t[@mel.meth]) ; names : string array > Js.t

let () =
  describe "Law B: never more than last time" (fun () ->
      test_long "no counter of a fixed Meltea program is above the checked-in baseline" (fun () ->
          Js.Promise.then_
            (fun (meltea : elm) ->
              let listed name counts = ("meltea: " ^ name, List.map (fun kind -> (kind, Counters.count counts kind)) Counters.kinds) in
              Ratchet.never_more_than_last_time ~part:"meltea" ~owned:[ "meltea: " ]
                (Array.to_list (Array.mapi (fun index name -> listed name (meltea##named index)) meltea##names)
                @ List.init 12 (fun index ->
                      listed ("random program, seed " ^ string_of_int (index + 1)) (meltea##random (Ratchet.seeded (index + 1)))));
              Js.Promise.resolve ())
            (Ratchet.loaded (Ratchet.path_of "meltea" "meltea_programs.mjs")))
        300_000)
