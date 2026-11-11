open Testing

external test_async : string -> (unit -> unit Js.Promise.t) -> unit = "test"

let ( let* ) promise next = Js.Promise.then_ next promise

let mount element =
  let root = attached () in
  let client = ReactDOM.Client.createRoot root in
  let* () = React.act (fun () -> ReactDOM.Client.render client element) in
  Js.Promise.resolve root

let () =
  describe "a module of the project named Array" (fun () ->
    test_async "takes the collection first, with no open in the files that use it" (fun () ->
      let row item = ((li ~key:item ~children:[ React.string item ] ()) [@JSX]) in
      let* inline = mount (Inline.make (Inline.makeProps ~items:[| "a"; "b" |] ())) in
      let* given = mount (Given.make (Given.makeProps ~items:[| "c"; "d" |] ~row ())) in
      expect (inner_html inline, inner_html given)
      |. to_equal ("<ul><li>a</li><li>b</li></ul>", "<ul><li>c</li><li>d</li></ul>");
      Js.Promise.resolve ()))
