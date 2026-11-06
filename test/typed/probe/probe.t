A test-only consumer of the typed pass, the probe, asks the type of every variable passed to a
function and wraps those typed Immediate in a check. Every mark is gone from the output:

  $ cat > react.mli <<'EOF'
  > val reason_react_is_also_in_this_build_remove_it : unit -> unit
  > EOF
  $ cat > typed_probe_runtime.mli <<'EOF'
  > val immediate : 'value -> 'value
  > val untyped : string -> unit
  > val typed : string -> asked:int -> answered:int -> immediate:int -> unit
  > EOF
  $ ocamlc -c react.mli typed_probe_runtime.mli
  $ cat > values.ml <<'EOF'
  > let count = 1
  > let items = [ count ]
  > let shown = (string_of_int count, List.length items, Array.make count items)
  > EOF
  $ ocamlc -stop-after parsing -dsource -ppx './pp.exe --as-ppx -typed' values.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let count = 1
  let items = [count]
  let shown =
    ((string_of_int (Typed_probe_runtime.immediate count)),
      (List.length items),
      (Array.make (Typed_probe_runtime.immediate count) items))
  let () =
    Typed_probe_runtime.typed "values.ml" ~asked:4 ~answered:4 ~immediate:2

Without -typed nothing is asked:

  $ ocamlc -stop-after parsing -dsource -ppx './pp.exe --as-ppx' values.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let count = 1
  let items = [count]
  let shown =
    ((string_of_int count), (List.length items), (Array.make count items))
  let () = Typed_probe_runtime.untyped "values.ml"

A file that does not type gets exactly that output, with no mark left:

  $ echo 'let broken = not_defined_anywhere' >> values.ml
  $ ocamlc -stop-after parsing -dsource -ppx './pp.exe --as-ppx' values.ml 2> untyped.ml
  $ ocamlc -stop-after parsing -dsource -ppx './pp.exe --as-ppx -typed' values.ml 2> typed.ml
  $ diff untyped.ml typed.ml
