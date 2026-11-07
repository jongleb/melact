With -meltea-hints, a component whose only hooks are useState and useReducer gets an alert that
points at it; one with any other hook gets nothing, and without the flag nothing changes:

  $ cat > screen.ml <<'EOF'
  > let make ~initial () =
  >   let count, setCount = React.useState (fun () -> initial) in
  >   let total, add = React.useReducer (fun total n -> total + n) 0 in
  >   ((button ~onClick:(fun _ -> setCount (fun n -> n + 1); add count) ~children:[ React.int total ] ()) [@JSX])
  > [@@react.component]
  > module Clock = struct
  >   let make () =
  >     let now, setNow = React.useState (fun () -> 0) in
  >     React.useEffect0 (fun () -> setNow (fun n -> n + 1); None);
  >     React.int now
  >   [@@react.component]
  > end
  > module Toggle = struct
  >   let make () =
  >     let on, setOn = React.useState (fun () -> false) in
  >     ((button ~onClick:(fun _ -> setOn not) ~children:[ React.string (if on then "on" else "off") ] ()) [@JSX])
  >   [@@react.component]
  > end
  > EOF
  $ ./pp.exe -meltea-hints -impl screen.ml | grep -c "Melact_hint.here"
  2
  $ ./pp.exe -meltea-hints -impl screen.ml | grep -o "make keeps its state in [0-9]* useState or useReducer cells*"
  make keeps its state in 2 useState or useReducer cells
  make keeps its state in 1 useState or useReducer cell
  $ ./pp.exe -impl screen.ml | grep -c "Melact_hint"
  0
  [1]
