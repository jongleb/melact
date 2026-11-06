type 'a key = Key of 'a Type.Id.t [@@unboxed]

(** A hook's value with the key of the call site that made it. *)
type slot = Slot : 'a key * 'a -> slot

type slots = { mutable items : slot array; mutable count : int; mutable cursor : int }

let key () = Key (Type.Id.make ())

external unchecked : unit key -> 'a key = "%identity"

type dependency

external listed : 'tuple -> dependency array = "%identity"

let slots () = { items = [||]; count = 0; cursor = 0 }
let rewind slots = slots.cursor <- 0

let found : type a. slots -> a key -> a option =
 fun slots (Key witness) ->
  let at = slots.cursor in
  match at < slots.count with
  | false -> None
  | true -> (
      slots.cursor <- at + 1;
      let (Slot (Key stored, value)) = Array.unsafe_get slots.items at in
      match Type.Id.provably_equal stored witness with
      | Some Equal -> Some value
      | None -> failwith "melact: hooks were called in a different order than in the previous render")

let put slots key value =
  let at = slots.cursor in
  slots.cursor <- at + 1;
  let slot = Slot (key, value) in
  (match at = Array.length slots.items with
  | true ->
      let grown = Array.make (max 4 (2 * at)) slot in
      Array.blit slots.items 0 grown 0 at;
      slots.items <- grown
  | false -> ());
  Array.unsafe_set slots.items at slot;
  slots.count <- at + 1
