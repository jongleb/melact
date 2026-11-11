open Testing

external test_async : string -> (unit -> unit Js.Promise.t) -> unit = "test"

let ( let* ) promise next = Js.Promise.then_ next promise

let mount element =
  let root = attached () in
  let client = ReactDOM.Client.createRoot root in
  let* () = React.act (fun () -> ReactDOM.Client.render client element) in
  Js.Promise.resolve (root, client)

let () =
  describe "reported code compiles and runs" (fun () ->
    test_async "hooks through open React, a module that includes React, -hook-modules and React.( )" (fun () ->
      let* opened, _ = mount (Findings.Opened.make (Findings.Opened.makeProps ())) in
      let* wrapped, _ = mount (Findings.Wrapped.make (Findings.Wrapped.makeProps ())) in
      let* () =
        React.act (fun () ->
          click (select opened "button");
          click (select wrapped "button"))
      in
      expect (inner_html opened, inner_html wrapped) |. to_equal ("<button>1</button>", "<button>11 21 31</button>");
      Js.Promise.resolve ());
    test_async "hooks in a file that starts with include React, in a component and in a custom hook" (fun () ->
      let* root, _ = mount (Included.make (Included.makeProps ())) in
      let* () = React.act (fun () -> click (select root "button")) in
      expect (inner_html root) |. to_equal "<button>1b</button>";
      Js.Promise.resolve ());
    test_async "a hook polymorphic in its value, used with two types" (fun () ->
      let* root, client = mount (Findings.Previous.make (Findings.Previous.makeProps ~count:1 ~label:"a" ())) in
      let* () =
        React.act (fun () ->
          ReactDOM.Client.render client (Findings.Previous.make (Findings.Previous.makeProps ~count:2 ~label:"b" ())))
      in
      let* () =
        React.act (fun () ->
          ReactDOM.Client.render client (Findings.Previous.make (Findings.Previous.makeProps ~count:3 ~label:"c" ())))
      in
      expect (inner_html root) |. to_equal "<p>2b</p>";
      Js.Promise.resolve ());
    test_async "dangerouslySetInnerHTML, a type props of the file's own, and ReactDOM.Ref.currentDomRef" (fun () ->
      let* inner, _ = mount (Findings.Inner.make (Findings.Inner.makeProps ~text:"<b>x</b>" ())) in
      let* own, _ = mount (Findings.Own.make (Findings.Own.makeProps ~x:7 ())) in
      let* _, _ = mount (Findings.Referred.make (Findings.Referred.makeProps ())) in
      expect (inner_html inner, inner_html own, !Findings.seen, ({ Findings.a = 1 }).a)
      |. to_equal ("<div><b>x</b></div>", "<div>7</div>", "input", 1);
      Js.Promise.resolve ());
    test_async "cached props whose type is declared in a module not opened, written with its bare names" (fun () ->
      let shown n =
        let k = string_of_int n in
        String.concat " "
          [ k; "strong1"; "all" ^ k; "soft"; "strong" ^ k; "soft" ^ k; "soft,strong" ^ k; "soft,strong" ^ k;
            "strong" ^ k; string_of_int (n + n); string_of_int (n + 1); "soft" ]
      in
      let* root, _ = mount (Disambiguated.make (Disambiguated.makeProps ())) in
      let rec clicks n seen =
        match n with
        | 4 -> Js.Promise.resolve (List.rev seen)
        | _ ->
            let* () = React.act (fun () -> click (select root "div")) in
            clicks (n + 1) (inner_html root :: seen)
      in
      let first = inner_html root in
      let* later = clicks 1 [] in
      expect (first :: later) |. to_equal (List.map (fun n -> "<div><p>" ^ shown n ^ "</p></div>") [ 0; 1; 2; 3 ]);
      Js.Promise.resolve ());
    test_async "lists mapped by an opened Array and List that take the collection first, as Belly's do" (fun () ->
      let* root, _ = mount (CollectionFirst.make (CollectionFirst.makeProps ())) in
      let row cells = "<tr>" ^ String.concat "" (List.map (fun cell -> "<td>" ^ cell ^ "</td>") cells) ^ "</tr>" in
      expect (inner_html root)
      |. to_equal
           ("<table><tbody>"
           ^ String.concat ""
               [
                 row [ "1"; "2" ]; row [ "1"; "2" ]; row [ "10"; "20" ]; row [ "1"; "2" ]; row [ "100"; "201" ]; row [ "7"; "8" ];
                 row [ "1"; "2" ]; row [ "3"; "4" ]; row [ "5"; "6" ];
               ]
           ^ "</tbody></table>");
      Js.Promise.resolve ());
    test_async "a function that ignores its argument, used at two types in a component with hooks" (fun () ->
      let* stated, _ = mount (PolyLet.Stated.make (PolyLet.Stated.makeProps ~busy:false ())) in
      let* effected, _ = mount (PolyLet.Effected.make (PolyLet.Effected.makeProps ~busy:false ())) in
      let closed = ref 0 in
      let* passed, _ = mount (PolyLet.Passed.make (PolyLet.Passed.makeProps ~busy:false ~onClose:(fun () -> incr closed) ())) in
      let* () =
        React.act (fun () ->
          click (select stated "button");
          click (select effected "button");
          click (select passed "button"))
      in
      expect (inner_html stated, inner_html effected, !closed)
      |. to_equal ("<div><button>x</button>2</div>", "<div><button>x</button>2</div>", 2);
      Js.Promise.resolve ());
    test_async "a function that reads its argument or annotates its result, used at two types in a component with hooks" (fun () ->
      let closed = ref 0 in
      let onClose () = incr closed in
      let* read, _ = mount (PolyLet.Read.make (PolyLet.Read.makeProps ~busy:false ~onClose ())) in
      let* stopped, _ = mount (PolyLet.Stopped.make (PolyLet.Stopped.makeProps ~busy:false ~onClose ())) in
      let* returned, _ = mount (PolyReturn.make (PolyReturn.makeProps ~busy:false ~onClose ())) in
      let* () =
        React.act (fun () ->
          click (select read "button");
          click (select stopped "button");
          click (select returned "button"))
      in
      expect !closed |. to_equal 5;
      Js.Promise.resolve ());
    test_async "a closed function and a row function, each used twice in a component with hooks" (fun () ->
      let closed = ref 0 in
      let* shut, _ = mount (PolyLet.Closed.make (PolyLet.Closed.makeProps ~busy:false ~onClose:(fun () -> incr closed) ())) in
      let* rows, _ = mount (PolyLet.Rows.make (PolyLet.Rows.makeProps ~items:[| "a"; "b" |] ~busy:false ())) in
      let* () = React.act (fun () -> click (select shut "button:last-child")) in
      expect (!closed, inner_html rows) |. to_equal (1, "<ul><li>a</li><li>b</li><li>last</li></ul>");
      Js.Promise.resolve ()))
