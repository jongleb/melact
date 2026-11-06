let () =
  let rows count =
    let adjectives =
      [| "pretty"; "large"; "big"; "small"; "tall"; "short"; "long"; "handsome"; "plain"; "quaint";
         "clean"; "elegant"; "easy"; "angry"; "crazy"; "helpful"; "mushy"; "odd"; "unsightly";
         "adorable"; "important"; "inexpensive"; "cheap"; "expensive"; "fancy" |]
    and colours =
      [| "red"; "yellow"; "blue"; "green"; "pink"; "brown"; "purple"; "brown"; "white"; "black";
         "orange" |]
    and nouns =
      [| "table"; "chair"; "house"; "bbq"; "desk"; "car"; "pony"; "cookie"; "sandwich"; "burger";
         "pizza"; "mouse"; "keyboard" |]
    in
    Array.init (int_of_string count) (fun index ->
        {
          Page.id = index + 1;
          label = adjectives.(index mod 25) ^ " " ^ colours.(index mod 11) ^ " " ^ nouns.(index mod 13);
        })
  in
  let page rows = ReactDOMServer.renderToString (Page.App.make (Page.App.makeProps ~rows ())) in
  match Sys.argv with
  | [| _; "html"; count |] -> print_string (page (rows count))
  | [| _; "time"; count; warmups; iterations |] ->
      let rows = rows count in
      let time () =
        let start = Unix.gettimeofday () in
        ignore (Sys.opaque_identity (page rows));
        (Unix.gettimeofday () -. start) *. 1000.
      in
      for _ = 1 to int_of_string warmups do
        ignore (time ())
      done;
      print_string
        ("["
        ^ String.concat "," (List.init (int_of_string iterations) (fun _ -> Printf.sprintf "%.4f" (time ())))
        ^ "]")
  | _ ->
      prerr_endline "usage: server.exe html N | server.exe time N WARMUPS ITERATIONS";
      exit 2
