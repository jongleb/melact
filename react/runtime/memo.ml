open Melhole

type t = View.input array

let unset = View.Input (ref ())
let cells key count = Instance.slot (Instance.current ()) key (fun () -> Array.make count unset)

let same cells at value =
  let (View.Input last) = Array.unsafe_get cells at in
  Dom_api.same last value

let kept cells at =
  let (View.Input value) = Array.unsafe_get cells at in
  Obj.magic value

let made cells at make =
  let value = make () in
  Array.unsafe_set cells at (View.Input value);
  value

let captured cells at value = Array.unsafe_set cells at (View.Input value)

let cached0 cells at make =
  match Dom_api.same (Array.unsafe_get cells at) unset with
  | true -> made cells at make
  | false -> kept cells at

let cached1 cells at a make =
  match same cells at a with
  | true -> kept cells (at + 1)
  | false ->
      captured cells at a;
      made cells (at + 1) make

let cached2 cells at a b make =
  match (same cells at a, same cells (at + 1) b) with
  | true, true -> kept cells (at + 2)
  | _ ->
      captured cells at a;
      captured cells (at + 1) b;
      made cells (at + 2) make

let cached3 cells at a b c make =
  match (same cells at a, same cells (at + 1) b, same cells (at + 2) c) with
  | true, true, true -> kept cells (at + 3)
  | _ ->
      captured cells at a;
      captured cells (at + 1) b;
      captured cells (at + 2) c;
      made cells (at + 3) make

let cached4 cells at a b c d make =
  match (same cells at a, same cells (at + 1) b, same cells (at + 2) c, same cells (at + 3) d) with
  | true, true, true, true -> kept cells (at + 4)
  | _ ->
      captured cells at a;
      captured cells (at + 1) b;
      captured cells (at + 2) c;
      captured cells (at + 3) d;
      made cells (at + 4) make

let cached cells at captures make =
  let count = Array.length captures in
  let rec fits index =
    match index = count with
    | true -> true
    | false ->
        let (View.Input value) = Array.unsafe_get captures index in
        same cells (at + index) value && fits (index + 1)
  in
  match fits 0 with
  | true -> kept cells (at + count)
  | false ->
      Array.blit captures 0 cells at count;
      made cells (at + count) make
