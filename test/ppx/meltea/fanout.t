A list whose rows hold a handler of a frequent event that reaches the list gets its alert, and is
still compiled into a loop (the alert sits apart from the handler):

  $ cat > typing.ml <<'EOF_'
  > type model = { chosen : int; draft : string }
  > type message = Retype of string | Pick of int
  > let update message model =
  >   match message with Retype draft -> { model with draft } | Pick chosen -> { model with chosen }
  > let cols = [| 0; 1; 2 |]
  > let view { chosen; draft } =
  >   ((table ~children:[ Html.array (Array.map (fun col -> ((td ~key:(string_of_int col) ~children:[ ((input ~value:draft ~onInput:(fun text -> Retype text) ~className:(string_of_int (chosen + col)) ()) [@JSX]) ] ()) [@JSX])) cols) ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -impl typing.ml | grep -c "View.rows"
  1
  $ ./pp.exe -impl typing.ml | grep -c "Melhole_fanout.here"
  1
