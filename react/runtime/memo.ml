open Melhole

type t = View.input array
type 'value found = 'value option

let unset = View.Input (ref ())
let cells key count = Instance.slot (Instance.current ()) key (fun () -> Array.make count unset)

let same cells at value =
  let (View.Input last) = Array.unsafe_get cells at in
  Dom_api.same last value

let captured cells at value = Array.unsafe_set cells at (View.Input value)

let held cells at =
  let (View.Input value) = Array.unsafe_get cells at in
  Some (Obj.magic value)

let lookup0 cells at =
  match Dom_api.same (Array.unsafe_get cells at) unset with true -> None | false -> held cells at

let lookup1 cells at a =
  match same cells at a with
  | true -> held cells (at + 1)
  | false ->
      captured cells at a;
      None

let lookup2 cells at a b =
  match (same cells at a, same cells (at + 1) b) with
  | true, true -> held cells (at + 2)
  | _ ->
      captured cells at a;
      captured cells (at + 1) b;
      None

let lookup3 cells at a b c =
  match (same cells at a, same cells (at + 1) b, same cells (at + 2) c) with
  | true, true, true -> held cells (at + 3)
  | _ ->
      captured cells at a;
      captured cells (at + 1) b;
      captured cells (at + 2) c;
      None

let lookup4 cells at a b c d =
  match (same cells at a, same cells (at + 1) b, same cells (at + 2) c, same cells (at + 3) d) with
  | true, true, true, true -> held cells (at + 4)
  | _ ->
      captured cells at a;
      captured cells (at + 1) b;
      captured cells (at + 2) c;
      captured cells (at + 3) d;
      None

let lookup cells at captures =
  let count = Array.length captures in
  let rec fits index =
    match index = count with
    | true -> true
    | false ->
        let (View.Input value) = Array.unsafe_get captures index in
        same cells (at + index) value && fits (index + 1)
  in
  match fits 0 with
  | true -> held cells (at + count)
  | false ->
      Array.blit captures 0 cells at count;
      None

external kept : 'value found -> 'value option = "%identity"

let store cells at (_ : 'value found) value =
  Array.unsafe_set cells at (View.Input value);
  value

let graph cells at changed mask = match changed land mask with 0 -> lookup0 cells at | _ -> None
