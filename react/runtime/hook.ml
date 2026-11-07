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
let skip slots = slots.cursor <- slots.cursor + 1
let position slots = slots.cursor

let found : type a. slots -> a key -> a option =
 fun slots (Key witness) ->
  let at = slots.cursor in
  if at < slots.count then (
    slots.cursor <- at + 1;
    let (Slot (Key stored, value)) = Array.unsafe_get slots.items at in
    match Type.Id.provably_equal stored witness with
    | Some Equal -> Some value
    | None -> Js.Exn.raiseError "melhole: hooks were called in a different order than in the previous render")
  else None

let put slots key value =
  let at = slots.cursor in
  slots.cursor <- at + 1;
  let slot = Slot (key, value) in
  if at = Array.length slots.items then begin
    let grown = Array.make (max 4 (2 * at)) slot in
    Array.blit slots.items 0 grown 0 at;
    slots.items <- grown
  end;
  Array.unsafe_set slots.items at slot;
  slots.count <- at + 1

let take slots key init =
  match found slots key with
  | Some value -> value
  | None ->
      let value = init () in
      put slots key value;
      value
