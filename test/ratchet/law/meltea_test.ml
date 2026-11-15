open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"

(** The build of the generated Meltea programs. *)
type elm =
  < random : (int array -> Counters.t[@mel.meth]) ; named : (int -> Counters.t[@mel.meth]) ; names : string array > Js.t

(** The keyed benchmark's operations as a Meltea program over arrays, one run each. *)
type keyed = < named : (int -> Counters.t[@mel.meth]) ; names : string array > Js.t

let () =
  describe "Law B: never more than last time" (fun () ->
      test_long "no counter of a fixed Meltea program is above the checked-in baseline" (fun () ->
          Js.Promise.then_
            (fun ((meltea : elm), (keyed : keyed)) ->
              let listed name counts = ("meltea: " ^ name, List.map (fun kind -> (kind, Counters.count counts kind)) Counters.kinds) in
              Ratchet.never_more_than_last_time ~part:"meltea" ~owned:[ "meltea: " ]
                (Array.to_list (Array.mapi (fun index name -> listed name (meltea##named index)) meltea##names)
                @ Array.to_list (Array.mapi (fun index name -> listed name (keyed##named index)) keyed##names)
                @ List.init 12 (fun index ->
                      listed ("random program, seed " ^ string_of_int (index + 1)) (meltea##random (Ratchet.seeded (index + 1)))));
              Js.Promise.resolve ())
            (Js.Promise.all2
               ( Ratchet.loaded (Ratchet.path_of "meltea" "meltea_programs.mjs"),
                 Ratchet.loaded (Ratchet.path_of "meltea" "meltea_keyed.mjs") )))
        300_000)

let () =
  describe "Counters.watched" (fun () ->
      test "counts every item read through the array, and neither its length nor reads that are not observed" (fun () ->
          let items = Counters.watched (Array.init 50 (fun index -> index)) in
          ignore (Counters.take ());
          let total = ref 0 in
          for index = 0 to Array.length items - 1 do
            if index mod 3 = 0 then total := !total + Array.unsafe_get items index
          done;
          Counters.unobserved (fun () -> ignore (Array.unsafe_get items 1));
          ignore (Array.length items);
          expect (Counters.count (Counters.take ()) Read, !total) |. to_equal (17, 408)))
