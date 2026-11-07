type build = React | Melact

(** The page module of a build. *)
type page = < start : (int -> unit[@mel.meth]) > Js.t

let ( let* ) promise next = Js.Promise.then_ next promise

let driven build rows chosen =
  let* steps = Classics.scenario "test/ratchet/bigpage/scenario.mjs" in
  let side = match build with React -> "react" | Melact -> "melact" in
  Classics.driven
    ~build:("_build/default/test/ratchet/bigpage/" ^ side ^ "/output/test/ratchet/bigpage/" ^ side ^ "/page.mjs?rows=" ^ string_of_int rows)
    ~start:(fun (page : page) -> page##start rows)
    (chosen steps)

let run build rows = driven build rows Fun.id

let keystroke build rows =
  let* run = driven build rows (Js.Array.slice ~start:0 ~end_:1) in
  Js.Promise.resolve (fst run##outcome).(1)
