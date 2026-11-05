let pending = ref [||]

let with_children children run =
  pending := children;
  match run () with
  | result ->
      pending := [||];
      result
  | exception error ->
      pending := [||];
      raise error

let take () =
  let children = !pending in
  pending := [||];
  children
