open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"
external print : string -> unit = "log" [@@mel.scope "console"]

(** How a bundle stands against test/ratchet/sizes.json, as test/ratchet/sizes.mjs reports it. *)
type verdict = < kind : string > Js.t

(** What a bundle did since the baseline. *)
type change = Shrunk | Not_shrunk

(** The baseline, test/ratchet/sizes.json. *)
type baseline

(** The size ratchet's module, test/ratchet/sizes.mjs. *)
type sizes =
  < measure : (unit -> int Js.Dict.t Js.Promise.t[@mel.meth])
  ; recorded : (unit -> baseline[@mel.meth])
  ; verdicts : (int Js.Dict.t -> baseline -> verdict array[@mel.meth])
  ; shown : (verdict -> string[@mel.meth]) >
  Js.t

let loaded : string -> sizes Js.Promise.t =
  [%mel.raw {|function (path) { return import(/* @vite-ignore */ process.cwd() + "/" + path); }|}]

let () =
  describe "The size ratchet" (fun () ->
      test_long "no production bundle is larger, gzipped, than test/ratchet/sizes.json records, and every bundle is recorded"
        (fun () ->
          Js.Promise.then_
            (fun (sizes : sizes) ->
              Js.Promise.then_
                (fun measured ->
                  let found = Array.to_list (sizes##verdicts measured (sizes##recorded ())) in
                  let changed verdict = match verdict##kind with "shrunk" -> Shrunk | _ -> Not_shrunk in
                  print
                    (String.concat "\n"
                       (("Sizes, gzip -9 bytes: "
                        ^ String.concat ", "
                            (List.map
                               (fun (name, size) -> name ^ " " ^ string_of_int size)
                               (Array.to_list (Js.Dict.entries measured))))
                       :: List.map (fun verdict -> "  " ^ sizes##shown verdict) found));
                  expect
                    (List.filter_map
                       (fun verdict -> match changed verdict with Shrunk -> None | Not_shrunk -> Some (sizes##shown verdict))
                       found)
                  |. to_equal [];
                  Js.Promise.resolve ())
                (sizes##measure ()))
            (loaded "test/ratchet/sizes.mjs"))
        120_000)
