let cases =
  [
    "v";
    "(div ~children:[ React.array v ] ()) [@JSX]";
    "(Row.createElement ~items:v ~children:[] ()) [@JSX]";
    "v |. Belt.Array.keep (fun x -> x > 1) |. Belt.Array.length";
    "List.length v + Array.length v";
    "match v with [||] -> 0 | _ -> 1";
    "if v = [||] then 0 else 1";
    "v.(0)";
    "v.(0) <- 1";
    "v := 1";
    "incr v";
    "v.field";
    "v.field <- 1";
    "Js.Array.push ~value:1 v";
    "Js.Array.map ~f:(fun x -> x) v";
    "React.useEffect1 (fun () -> None) [| v |]";
    "unknown v";
    "(v, 1)";
    "{ items = v }";
    "let w = v in w";
    "let v = [||] in Js.Array.push ~value:1 v";
    "fun v -> v := 1";
    "fun () -> Js.Array.push ~value:1 v";
    "fun () -> Array.length v";
    "match x with Some v -> v := 1 | None -> ()";
    "match x with Some w -> w := 1 | None -> v := 2";
  ]

let () =
  List.iter
    (fun source ->
      let verdict =
        match Melact_ppx.Frozen.uses "v" (Ppxlib.Parse.expression (Lexing.from_string source)) with
        | Melact_ppx.Frozen.Read_only -> "read only"
        | Melact_ppx.Frozen.Possibly_changed -> "possibly changed"
      in
      Printf.printf "%-62s %s\n" source verdict)
    cases
