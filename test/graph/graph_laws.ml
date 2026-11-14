open QCheck2

(** When the code a generator writes runs: while the component renders, while it renders for a value only the first
    render keeps (the argument of [useState] or [useRef]), or when something calls it later. *)
type timing = Rendering | First | Later

(** A component body as source, and whether its render reads the world, as the generator built it. *)
type body = { source : string; rendering : Melact_ppx.Graph.rendering }

let reads = [ "row.current"; "!counter"; "Js.Date.now ()"; "measure ()" ]
let writes = [ "(counter := 1; 0)"; "useThing x"; "(object_ # size)"; "(let cell = counter in cell := 1; 0)" ]

let pure_atoms =
  [ "x"; "count"; "item.title"; "String.length name"; "(count + 1)"; "\"text\""; "Some x"; "(let cell = ref 0 in cell := 1; incr cell; !cell)"; "(fst (useTracked x))" ]

let joined first second =
  match (first, second) with
  | Melact_ppx.Graph.Impure, _ | _, Melact_ppx.Graph.Impure -> Melact_ppx.Graph.Impure
  | Melact_ppx.Graph.Reads_the_page, _ | _, Melact_ppx.Graph.Reads_the_page -> Melact_ppx.Graph.Reads_the_page
  | Melact_ppx.Graph.Pure, Melact_ppx.Graph.Pure -> Melact_ppx.Graph.Pure

let both first second = joined first.rendering second.rendering

let rec body depth timing =
  let open Gen in
  let atom =
    oneof
      [
        map (fun source -> { source; rendering = Melact_ppx.Graph.Pure }) (oneof_list pure_atoms);
        map
          (fun source ->
            { source; rendering = (match timing with Rendering -> Melact_ppx.Graph.Impure | First | Later -> Melact_ppx.Graph.Pure) })
          (oneof_list reads);
        map
          (fun source ->
            { source; rendering = (match timing with Rendering | First -> Melact_ppx.Graph.Impure | Later -> Melact_ppx.Graph.Pure) })
          (oneof_list writes);
      ]
  in
  match depth with
  | 0 -> atom
  | _ ->
      let now = body (depth - 1) timing
      and first = body (depth - 1) (match timing with Rendering | First -> First | Later -> Later)
      and later = body (depth - 1) Later in
      let two shape first second =
        map2 (fun a b -> { source = shape ("(" ^ a.source ^ ")") ("(" ^ b.source ^ ")"); rendering = both a b }) first second
      in
      oneof
        [
          atom;
          two (Printf.sprintf "(let y = %s in ignore y; %s)") now now;
          two (Printf.sprintf "(match %s with _ -> %s)") now now;
          two
            (Printf.sprintf "(div ~onClick:(fun _ -> ignore %s) ~title:%s ~children:[] () [@JSX])")
            later now;
          two
            (Printf.sprintf "(Row.createElement ~onSelect:(fun () -> ignore %s) ~value:%s ~children:[] () [@JSX])")
            later now;
          two (Printf.sprintf "(React.useEffect1 (fun () -> ignore %s; None) [| %s |]; 0)") later now;
          two (Printf.sprintf "(React.useLayoutEffect (fun () -> ignore %s; None); %s)") later now;
          two (Printf.sprintf "(React.useCallback1 (fun z -> ignore z; %s) [| %s |])") later now;
          two (Printf.sprintf "(fst (React.useReducer (fun state _ -> ignore %s; state) %s))") later first;
          two (Printf.sprintf "(React.useMemo1 (fun () -> %s) [| %s |])") now now;
          two (Printf.sprintf "(fst (React.useState (fun () -> %s)) + String.length %s)") first now;
          two (Printf.sprintf "(fst (React.useState %s) + String.length %s)") first now;
          two (Printf.sprintf "(let kept = React.useRef %s in ignore kept; %s)") first now;
          two (Printf.sprintf "(Array.map (fun i -> ignore i; %s) %s)") now now;
          two (Printf.sprintf "(let f = fun w -> ignore w; %s in f %s)") now now;
          map2
            (fun a b ->
              {
                source = Printf.sprintf "(let mine = React.useRef 0 in ignore (%s); mine.current + String.length (%s))" a.source b.source;
                rendering =
                  joined (both a b) (match timing with Rendering -> Melact_ppx.Graph.Reads_the_page | First | Later -> Melact_ppx.Graph.Pure);
              })
            now now;
          map2
            (fun a b ->
              {
                source = Printf.sprintf "(let mine = React.useRef 0 in mine.current <- String.length (%s); %s)" a.source b.source;
                rendering = joined (both a b) (match timing with Rendering | First -> Melact_ppx.Graph.Impure | Later -> Melact_ppx.Graph.Pure);
              })
            now now;
          map2
            (fun a b ->
              {
                source = Printf.sprintf "(let mine = React.useRef 0 in let mine = row in ignore (%s); mine.current + String.length (%s))" a.source b.source;
                rendering = joined (both a b) (match timing with Rendering -> Melact_ppx.Graph.Impure | First | Later -> Melact_ppx.Graph.Pure);
              })
            now now;
        ]

let law =
  Test.make
    ~name:
      "Graph: a render reads the world exactly when a read of the world is evaluated while it renders for a value every render \
       keeps, or a write while it renders at all, and only the page when that read is the current of a ref it made"
    ~count:2000
    ~print:(fun { source; _ } -> source)
    (Gen.sized_size (Gen.int_bound 5) (fun depth -> body depth Rendering))
    (fun { source; rendering } ->
      let hooks callee =
        match callee.Ppxlib.pexp_desc with Pexp_ident { txt = Lident "useTracked"; _ } -> Some 1 | _ -> None
      in
      Melact_ppx.Graph.rendering ~hooks (Ppxlib.Parse.expression (Lexing.from_string source)) = rendering)

let () = exit (QCheck_base_runner.run_tests ~verbose:true [ law ])
