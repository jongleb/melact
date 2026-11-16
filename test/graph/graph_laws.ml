open QCheck2

(** When the code a generator writes runs: while the component renders, while it renders for a value only the first
    render keeps (the argument of [useState] or [useRef]), or when something calls it later. *)
type timing = Rendering | First | Later

(** Whether a render reads only what React lets it read, as the generator built it. *)
type seen = Pure | Reads_the_page | Impure

(** A component body as source, and whether its render reads the world, as the generator built it. *)
type body = { source : string; rendering : seen }

let reads = [ "row.current"; "!counter"; "Js.Date.now ()"; "measure ()" ]
let writes = [ "(counter := 1; 0)"; "useThing x"; "(object_ # size)"; "(let cell = counter in cell := 1; 0)" ]

let pure_atoms =
  [ "x"; "count"; "item.title"; "String.length name"; "(count + 1)"; "\"text\""; "Some x"; "(let cell = ref 0 in cell := 1; incr cell; !cell)"; "(fst (useTracked x))" ]

let joined first second =
  match (first, second) with
  | Impure, _ | _, Impure -> Impure
  | Reads_the_page, _ | _, Reads_the_page -> Reads_the_page
  | Pure, Pure -> Pure

let both first second = joined first.rendering second.rendering

let rec body depth timing =
  let open Gen in
  let atom =
    oneof
      [
        map (fun source -> { source; rendering = Pure }) (oneof_list pure_atoms);
        map
          (fun source ->
            { source; rendering = (match timing with Rendering -> Impure | First | Later -> Pure) })
          (oneof_list reads);
        map
          (fun source ->
            { source; rendering = (match timing with Rendering | First -> Impure | Later -> Pure) })
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
          two (Printf.sprintf "(useLater (fun () -> %s) (fun () -> %s))") later now;
          two (Printf.sprintf "(useLater ~onDone:(fun () -> ignore %s) (fun () -> 0) (fun () -> %s))") later now;
          two (Printf.sprintf "(useLater ~onDone:(fun () -> ()) (fun () -> %s) (fun () -> %s))") later now;
          two (Printf.sprintf "(useTracked (fun () -> %s) + String.length %s)") now now;
          two (Printf.sprintf "(plainLater (fun () -> %s) %s)") later now;
          map
            (fun a ->
              {
                source = Printf.sprintf "(pageHook x ^ %s)" a.source;
                rendering = joined a.rendering (match timing with Rendering -> Reads_the_page | First | Later -> Pure);
              })
            now;
          map
            (fun a ->
              {
                source = Printf.sprintf "(ignore (opaque x); %s)" a.source;
                rendering = joined a.rendering (match timing with Rendering | First -> Impure | Later -> Pure);
              })
            now;
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
                  joined (both a b) (match timing with Rendering -> Reads_the_page | First | Later -> Pure);
              })
            now now;
          map2
            (fun a b ->
              {
                source = Printf.sprintf "(let mine = React.useRef 0 in mine.current <- String.length (%s); %s)" a.source b.source;
                rendering = joined (both a b) (match timing with Rendering | First -> Impure | Later -> Pure);
              })
            now now;
          map2
            (fun a b ->
              {
                source = Printf.sprintf "(let mine = React.useRef 0 in let mine = row in ignore (%s); mine.current + String.length (%s))" a.source b.source;
                rendering = joined (both a b) (match timing with Rendering -> Impure | First | Later -> Pure);
              })
            now now;
        ]

let summaries callee =
  let counted ?(page = Melact_ppx.Graph.Unread) later =
    Some (Melact_ppx.Graph.Counted { Melact_ppx.Graph.slots = 1; through = []; later; page })
  in
  match callee.Ppxlib.pexp_desc with
  | Pexp_ident { txt = Lident "useTracked"; _ } -> counted []
  | Pexp_ident { txt = Lident "useLater"; _ } -> counted [ Melact_ppx.Graph.Position 0; Melact_ppx.Graph.Label "onDone" ]
  | Pexp_ident { txt = Lident "plainLater"; _ } -> counted [ Melact_ppx.Graph.Position 0 ]
  | Pexp_ident { txt = Lident "pageHook"; _ } -> counted ~page:Melact_ppx.Graph.Read []
  | Pexp_ident { txt = Lident "opaque"; _ } -> Some Melact_ppx.Graph.Uncounted
  | _ -> None

let law =
  Test.make
    ~name:
      "Graph: a render reads the world exactly when a read of the world is evaluated while it renders for a value every render \
       keeps, or a write while it renders at all, and only the page when that read is the current of a ref it made"
    ~count:2000
    ~print:(fun { source; _ } -> source)
    (Gen.sized_size (Gen.int_bound 5) (fun depth -> body depth Rendering))
    (fun { source; rendering } ->
      let hooks = summaries in
      (match Melact_ppx.Graph.rendering ~hooks (Ppxlib.Parse.expression (Lexing.from_string source)) with
      | Melact_ppx.Graph.Pure -> Pure
      | Melact_ppx.Graph.Reads_the_page _ -> Reads_the_page
      | Melact_ppx.Graph.Impure _ -> Impure)
      = rendering)

let explained =
  Test.make
    ~name:
      "Graph: why a render reads the world points at a read or a write of the world, an unknown hook or a construct \
       melact-ppx does not read, and at nothing around it"
    ~count:2000
    ~print:(fun { source; _ } -> source)
    (Gen.sized_size (Gen.int_bound 5) (fun depth -> body depth Rendering))
    (fun { source; _ } ->
      let hooks = summaries in
      match Melact_ppx.Graph.rendering ~hooks (Ppxlib.Parse.expression (Lexing.from_string source)) with
      | Melact_ppx.Graph.Pure -> true
      | Melact_ppx.Graph.Reads_the_page { loc; _ } | Melact_ppx.Graph.Impure { loc; _ } ->
          let start = loc.loc_start.pos_cnum and stop = loc.loc_end.pos_cnum in
          let rec bare text =
            let length = String.length text in
            match length >= 2 && text.[0] = '(' && text.[length - 1] = ')' with
            | true -> bare (String.trim (String.sub text 1 (length - 2)))
            | false -> text
          in
          let pointed = bare (String.sub source start (stop - start)) in
          let contains whole part =
            let rec from index =
              index + String.length part <= String.length whole
              && (String.equal (String.sub whole index (String.length part)) part || from (index + 1))
            in
            from 0
          in
          List.exists (fun atom -> contains atom pointed) (reads @ writes @ [ "mine.current"; "pageHook x"; "opaque x" ])
          || String.starts_with ~prefix:"mine.current <- " pointed
          || Test.fail_reportf "points at %S" pointed)

(** When a use of a custom hook's parameter in the hook's body calls it: during the render, or only after it. *)
type moment = During | After

let uses =
  [
    (After, Printf.sprintf "React.useEffect0 (fun () -> ignore (%s 1); None)");
    (After, Printf.sprintf "React.useEffect0 %s");
    (After, Printf.sprintf "React.useCallback0 (fun z -> %s z)");
    (After, Printf.sprintf "React.useReducer (fun state _ -> %s state) 0");
    (After, Printf.sprintf "useLater %s (fun () -> 0)");
    (After, Printf.sprintf "useLater (fun () -> %s 1) (fun () -> 0)");
    (After, Printf.sprintf "useLater ~onDone:%s (fun () -> 0) (fun () -> 0)");
    (After, Printf.sprintf "(div ~onClick:%s ~children:[] () [@JSX])");
    (During, Printf.sprintf "%s 1");
    (During, Printf.sprintf "React.useMemo0 (fun () -> %s 1)");
    (During, Printf.sprintf "React.useState (fun () -> %s 1)");
    (During, Printf.sprintf "useLater (fun () -> 0) %s");
    (During, Printf.sprintf "useLater (fun () -> 0) (fun () -> %s 1)");
    (During, Printf.sprintf "useTracked %s");
    (During, Printf.sprintf "(let kept = %s in kept)");
    (During, Printf.sprintf "(div ~children:[ %s 1 ] () [@JSX])");
  ]

let later_law =
  let parameters = [ ("fetch", Melact_ppx.Graph.Position 0); ("onDone", Melact_ppx.Graph.Label "onDone"); ("other", Melact_ppx.Graph.Position 1) ] in
  Test.make
    ~name:
      "Graph: a custom hook's fact holds the parameters it calls only after the render, those every use of which is in an \
       effect, a callback, a reducer, a handler or an argument another hook calls later"
    ~count:2000
    ~print:(fun picked -> String.concat "; " (List.map (fun ((name, _), (_, use)) -> use name) picked))
    Gen.(list_size (int_bound 6) (pair (oneof_list parameters) (oneof_list uses)))
    (fun picked ->
      let source =
        Printf.sprintf "fun fetch ~onDone other -> %s0"
          (String.concat "" (List.mapi (fun index ((name, _), (_, use)) -> Printf.sprintf "let _use%d = %s in " index (use name)) picked))
      in
      let hooks callee =
        let known later =
          Some
            (Melact_ppx.Graph.Counted
               { Melact_ppx.Graph.fact = { slots = 1; through = []; later; page = Melact_ppx.Graph.Unread }; values = []; conditions = [] })
        in
        match callee.Ppxlib.pexp_desc with
        | Pexp_ident { txt = Lident "useTracked"; _ } -> known []
        | Pexp_ident { txt = Lident "useLater"; _ } -> known [ Melact_ppx.Graph.Position 0; Melact_ppx.Graph.Label "onDone" ]
        | _ -> None
      in
      let expected =
        List.filter_map
          (fun (name, argument) ->
            match List.exists (fun ((used, _), (moment, _)) -> String.equal used name && moment = During) picked with
            | true -> None
            | false -> Some argument)
          parameters
      in
      match Melact_ppx.Graph.slots ~hooks (Ppxlib.Parse.expression (Lexing.from_string source)) with
      | Ok { fact = { later; _ }; _ } -> later = expected || Test.fail_reportf "%s: later is wrong" source
      | Error { reason; _ } -> Test.fail_reportf "%s: no fact, as it %s" source reason)

(** Where a step of a generated body calls a hook: as the value of its let, or inside an expression. *)
type place = Top | Nested

let hooked_law =
  Test.make
    ~name:
      "Graph: a hook known by its fact counts whatever its name: the update graph and a hook's fact take it only as the \
       value of a let, a hook that could not be counted stops both, and one that reads the page makes what reads it \
       run on every render"
    ~count:2000
    ~print:(fun steps -> String.concat "; " (List.map (fun (callee, place) -> callee ^ (match place with Top -> "" | Nested -> " nested")) steps))
    Gen.(list_size (int_range 1 5) (pair (oneof_list [ "plainLater"; "pageHook"; "opaque" ]) (oneof_list [ Top; Nested ])))
    (fun steps ->
      let lets =
        String.concat ""
          (List.mapi
             (fun index (callee, place) ->
               match place with
               | Top -> Printf.sprintf "let a%d = %s x in " index callee
               | Nested -> Printf.sprintf "let a%d = String.length (%s x) in " index callee)
             steps)
      in
      let result = String.concat " ^ " (List.mapi (fun index _ -> Printf.sprintf "a%d" index) steps) in
      let counted callee = Option.map (fun summary -> match summary with Melact_ppx.Graph.Counted fact -> Melact_ppx.Graph.Counted { Melact_ppx.Graph.fact; values = []; conditions = [] } | Melact_ppx.Graph.Uncounted -> Melact_ppx.Graph.Uncounted) (summaries callee) in
      let facts callee = Option.bind (summaries callee) (fun summary -> match summary with Melact_ppx.Graph.Counted fact -> Some fact | Melact_ppx.Graph.Uncounted -> None) in
      let parse text = Ppxlib.Parse.expression (Lexing.from_string text) in
      let countable = List.for_all (fun (callee, place) -> place = Top && not (String.equal callee "opaque")) steps in
      let reads_page = List.exists (fun (callee, _) -> String.equal callee "pageHook") steps in
      let plannable = not (List.exists (fun (callee, place) -> place = Nested && not (String.equal callee "opaque")) steps) in
      let planned =
        match
          ( Melact_ppx.Graph.plan ~hooks:facts ~inputs:0 ~props:[ ("x", 1) ] ~volatile:Melact_ppx.Graph.Runs_every_render
              (parse (lets ^ result)),
            plannable )
        with
        | Ok { reads; _ }, true -> (
            match List.exists (fun (callee, _) -> String.equal callee "opaque") steps with
            | true -> true
            | false -> (reads = Melact_ppx.Graph.every_source) = reads_page || Test.fail_reportf "reads %d" reads)
        | Error _, false -> true
        | Ok _, false -> Test.fail_report "a plan around a hook called inside an expression"
        | Error { reason; _ }, true -> Test.fail_reportf "no plan, as it %s" reason
      in
      planned
      &&
      match (Melact_ppx.Graph.slots ~hooks:counted (parse ("fun x -> " ^ lets ^ result)), countable) with
      | Ok { fact = { page; _ }; _ }, true -> (page = Melact_ppx.Graph.Read) = reads_page || Test.fail_report "page is wrong"
      | Error _, false -> true
      | Ok _, false -> Test.fail_report "a fact for a hook that cannot be counted"
      | Error { reason; _ }, true -> Test.fail_reportf "no fact, as it %s" reason)

let () = exit (QCheck_base_runner.run_tests ~verbose:true [ law; explained; later_law; hooked_law ])
