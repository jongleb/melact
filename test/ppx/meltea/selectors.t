A leaf of a row that differs between rows only in whether the row's key is the chosen one becomes a
selector: the loop gets the key the outer values choose, a row's key, and as bits of its outer
inputs (dispatch, then the locals in order) those its other pieces read. Every other shape stays a
plain projected leaf, and a loop without selectors is Unselecting.

  $ row () {
  >   printf 'let view (rows, chosen, extra, offset) =\n  let row (id, label) = ((li ~key:(string_of_int id) %s ~children:[ Html.text label ] ()) [@JSX]) in\n  ((ul ~children:[ Html.list (List.map row rows) ] ()) [@JSX])\n' "$1" > row.ml
  >   ./pp.exe -impl row.ml | grep -o "Melhole.View.selection [0-9]*\|Melhole.View.Unselecting\|Melhole.View.selector Melhole.View.[A-Za-z]*"
  > }

The guard compares the one variable of the pattern with a row's key, on either side, with = or ==:

  $ row '~className:(match chosen with Some k when k = id -> "on" | _ -> "")'
  Melhole.View.selection 1
  Melhole.View.selector Melhole.View.Structural
  $ row '~className:(match chosen with Some k when id = k -> "on" | _ -> "")'
  Melhole.View.selection 1
  Melhole.View.selector Melhole.View.Structural
  $ row '~className:(match chosen with Some k when k == id -> "on" | _ -> "")'
  Melhole.View.selection 1
  Melhole.View.selector Melhole.View.Physical
  $ row '~className:(if id = chosen then "on" else "")'
  Melhole.View.selection 1
  Melhole.View.selector Melhole.View.Structural
  $ row '~className:(if chosen + offset = id then "on" else "")'
  Melhole.View.selection 1
  Melhole.View.selector Melhole.View.Structural

The last case may be any pattern that binds nothing:

  $ row '~className:(match chosen with Some k when k = id -> "on" | Some _ | None -> "")'
  Melhole.View.selection 1
  Melhole.View.selector Melhole.View.Structural

The branches may read the row; a piece beside the selector that reads extra marks it as read:

  $ row '~className:(match chosen with Some k when k = id -> "on " ^ label | _ -> label)'
  Melhole.View.selection 1
  Melhole.View.selector Melhole.View.Structural
  $ row '~className:(match chosen with Some k when k = id -> "on" | _ -> "") ~title:(extra ^ label)'
  Melhole.View.selection 5
  Melhole.View.selector Melhole.View.Structural

What is chosen reads only outer names, a row's key only the row's:

  $ row '~className:(match chosen with Some k when k = id -> "on" | _ -> "")' > /dev/null
  $ ./pp.exe -impl row.ml | sed -n '/Melhole.View.Selecting/,/|\]/p'
                         (Melhole.View.Selecting
                            (__melhole_selection_3,
                              [|(Melhole.View.selector Melhole.View.Structural
                                   ((match chosen with
                                     | Some k -> Some k
                                     | _ -> None)[@ocaml.warning "-11"])
                                   {
                                     Js.Fn.I2 =
                                       (fun __melhole_item __melhole_index ->
                                          ((let (id, label) = __melhole_item in
                                            id)
                                          [@ocaml.warning "-26-27"]))
                                   })|])));

Rejected: a third case, a branch that reads an outer name or the bound variable, a pattern that
binds two variables or a last one that binds any, a matched value that reads the row, a key that reads an outer name, and a
guard that is not an equality:

  $ row '~className:(match chosen with Some k when k = id -> "on" | None -> "none" | _ -> "")'
  Melhole.View.Unselecting
  $ row '~className:(match chosen with Some k when k = id -> extra | _ -> "")'
  Melhole.View.Unselecting
  $ row '~className:(match chosen with Some k when k = id -> k | _ -> "")'
  Melhole.View.Unselecting
  $ row '~className:(match chosen with Some (k, j) when k = id -> "on" | _ -> "")'
  Melhole.View.Unselecting
  $ row '~className:(match chosen with Some k when k = id -> "on" | other -> "")'
  Melhole.View.Unselecting
  $ row '~className:(match (chosen, label) with (Some k, _) when k = id -> "on" | _ -> "")'
  Melhole.View.Unselecting
  $ row '~className:(match chosen with Some k when k = id + offset -> "on" | _ -> "")'
  Melhole.View.Unselecting
  $ row '~className:(match chosen with Some k when k > id -> "on" | _ -> "")'
  Melhole.View.Unselecting

Html.array over Array.map is the same keyed loop, reading the array as it is, and Html.list over
List.map makes its array from the list only when the list changes:

  $ cat > arrays.ml <<'EOF_'
  > let by_array rows = ((ul ~children:[ Html.array (Array.map (fun id -> ((li ~key:(string_of_int id) ~children:[ Html.int id ] ()) [@JSX])) rows) ] ()) [@JSX])
  > let by_list rows = ((ul ~children:[ Html.list (List.map (fun id -> ((li ~key:(string_of_int id) ~children:[ Html.int id ] ()) [@JSX])) rows) ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -impl arrays.ml | grep -o "Melhole.View.rows [a-z_]* [A-Za-z_.]*"
  Melhole.View.rows rows Melhole.View.arrayed
  Melhole.View.rows rows Stdlib.Array.of_list
