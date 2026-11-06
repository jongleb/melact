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
      Js.Promise.resolve ()))
