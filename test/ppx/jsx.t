A static tree becomes one template and one hoisted element:

  $ cat > static.ml <<'EOF'
  > let header = ((header ~className:"top" ~children:[ ((h1 ~children:[ React.string "Hi & <bye>" ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl static.ml
  let __melact_template_1 =
    Melact_view.Template.make
      ~html:"<header class=\"top\"><h1>Hi &amp; &lt;bye&gt;</h1></header>"
      ~holes:[||]
  let __melact_element_2 =
    React.Element (Melact_view.View.tpl_instance __melact_template_1 [||])
  let header = __melact_element_2

Holes at every depth; markers only between neighbours that would merge:

  $ cat > holes.ml <<'EOF'
  > let row ~name ~count ~extra =
  >   ((p ~children:[ React.string "a"; React.string name; React.string "b"; extra; extra;
  >                   ((b ~children:[ React.int count ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl holes.ml
  let __melact_template_1 =
    Melact_view.Template.make ~html:"<p>a<!---->b<!----><b></b></p>"
      ~holes:[|(Melact_view.Template.Text ([], 1));(Melact_view.Template.Child
                                                      ([], 3));(Melact_view.Template.Child
                                                                  ([], 4));(
               Melact_view.Template.Text ([4], 0))|]
  let row ~name ~count ~extra =
    React.Element
      (Melact_view.View.guarded __melact_template_1 3
         (fun __melact_block ->
            let __melact_changed_0 =
              Melact_view.View.check __melact_block 0 count in
            let __melact_changed_1 =
              Melact_view.View.check __melact_block 1 extra in
            let __melact_changed_2 =
              Melact_view.View.check __melact_block 2 name in
            (match __melact_changed_2 with
             | Melact_view.View.Unchanged -> ()
             | _ ->
                 Melact_view.View.put __melact_block 0
                   (Melact_view.View.HText (name : string)));
            (match __melact_changed_1 with
             | Melact_view.View.Unchanged -> ()
             | _ ->
                 Melact_view.View.put __melact_block 1
                   (Melact_view.View.HChild
                      (let React.Element __melact_child = extra in
                       __melact_child)));
            (match __melact_changed_1 with
             | Melact_view.View.Unchanged -> ()
             | _ ->
                 Melact_view.View.put __melact_block 2
                   (Melact_view.View.HChild
                      (let React.Element __melact_child = extra in
                       __melact_child)));
            (match __melact_changed_0 with
             | Melact_view.View.Unchanged -> ()
             | _ ->
                 Melact_view.View.put __melact_block 3
                   (Melact_view.View.HText (string_of_int (count : int))));
            ()))

Every kind of prop, static and dynamic, required and optional:

  $ cat > props.ml <<'EOF'
  > let form ~text ~flag ~tab ~opacity ~style ~ref ~maybe ~html ~onInput =
  >   ((input ~className:text ~id:"name" ~disabled:flag ~required:true ~readOnly:false
  >      ~ariaHidden:flag ~tabIndex:tab ~maxLength:3 ~value:text ~checked:flag
  >      ~style ~ref ?title:maybe ~onChange:onInput ?onKeyDown:None ()) [@JSX]),
  >   ((div ~dangerouslySetInnerHTML:html ~strokeWidth:"2" ~htmlFor:"x" ()) [@JSX])
  > EOF
  $ ./pp.exe -impl props.ml
  let __melact_template_1 =
    Melact_view.Template.make
      ~html:"<input id=\"name\" required maxLength=\"3\">"
      ~holes:[|(Melact_view.Template.Attr ([], "class"));(Melact_view.Template.Attr
                                                            ([], "disabled"));(
               Melact_view.Template.Attr ([], "aria-hidden"));(Melact_view.Template.Attr
                                                                 ([],
                                                                   "tabIndex"));(
               Melact_view.Template.Prop ([], "value"));(Melact_view.Template.Prop
                                                           ([], "checked"));(
               Melact_view.Template.Style []);(Melact_view.Template.Ref []);(
               Melact_view.Template.Attr ([], "title"));(Melact_view.Template.Handler
                                                           ([], "input"));(
               Melact_view.Template.Handler ([], "keydown"))|]
  let __melact_template_2 =
    Melact_view.Template.make ~html:"<div stroke-width=\"2\" for=\"x\"></div>"
      ~holes:[|(Melact_view.Template.Prop ([], "innerHTML"))|]
  let form ~text ~flag ~tab ~opacity ~style ~ref ~maybe ~html ~onInput =
    ((React.Element
        (Melact_view.View.guarded __melact_template_1 5
           (fun __melact_block ->
              let __melact_changed_0 =
                Melact_view.View.check __melact_block 0 flag in
              let __melact_changed_1 =
                Melact_view.View.check __melact_block 1 maybe in
              let __melact_changed_2 =
                Melact_view.View.check __melact_block 2 style in
              let __melact_changed_3 =
                Melact_view.View.check __melact_block 3 tab in
              let __melact_changed_4 =
                Melact_view.View.check __melact_block 4 text in
              (match __melact_changed_4 with
               | Melact_view.View.Unchanged -> ()
               | _ ->
                   Melact_view.View.put __melact_block 0
                     (Melact_view.View.HAttr (Some (text : string))));
              (match __melact_changed_0 with
               | Melact_view.View.Unchanged -> ()
               | _ ->
                   Melact_view.View.put __melact_block 1
                     (Melact_view.View.HAttr
                        (if (flag : bool) then Some "" else None)));
              (match __melact_changed_0 with
               | Melact_view.View.Unchanged -> ()
               | _ ->
                   Melact_view.View.put __melact_block 2
                     (Melact_view.View.HAttr
                        (Some (if (flag : bool) then "true" else "false"))));
              (match __melact_changed_3 with
               | Melact_view.View.Unchanged -> ()
               | _ ->
                   Melact_view.View.put __melact_block 3
                     (Melact_view.View.HAttr (Some (string_of_int (tab : int)))));
              (match __melact_changed_4 with
               | Melact_view.View.Unchanged -> ()
               | _ ->
                   Melact_view.View.put __melact_block 4
                     (Melact_view.View.HProp (text : string)));
              (match __melact_changed_0 with
               | Melact_view.View.Unchanged -> ()
               | _ ->
                   Melact_view.View.put __melact_block 5
                     (Melact_view.View.HProp (flag : bool)));
              (match __melact_changed_2 with
               | Melact_view.View.Unchanged -> ()
               | _ ->
                   Melact_view.View.put __melact_block 6
                     (Melact_view.View.HStyle
                        (ReactDOM.Style.declarations style)));
              Melact_view.View.put __melact_block 7
                (Melact_view.View.HRef (ReactDOM.Ref.attach ref));
              (match __melact_changed_1 with
               | Melact_view.View.Unchanged -> ()
               | _ ->
                   Melact_view.View.put __melact_block 8
                     (Melact_view.View.HAttr (maybe : string option)));
              Melact_view.View.put __melact_block 9
                (Melact_view.View.HHandler
                   (fun __melact_event ->
                      onInput (ReactEvent.Form.Native __melact_event)));
              Melact_view.View.put __melact_block 10
                (Melact_view.View.HHandler
                   (fun __melact_event ->
                      Option.iter
                        (fun handle ->
                           handle (ReactEvent.Keyboard.Native __melact_event))
                        None));
              ()))),
      (React.Element
         (Melact_view.View.guarded __melact_template_2 1
            (fun __melact_block ->
               let __melact_changed_0 =
                 Melact_view.View.check __melact_block 0 html in
               (match __melact_changed_0 with
                | Melact_view.View.Unchanged -> ()
                | _ ->
                    Melact_view.View.put __melact_block 0
                      (Melact_view.View.HProp (html ## __html)));
               ()))))

A component with optional, defaulted and children props, and its signature:

  $ cat > card.ml <<'EOF'
  > let make ~title ?(size = 1) ?subtitle ~children () =
  >   ((section ~children:[ React.string title; children ] ()) [@JSX])
  > [@@react.component]
  > let nothing = fun () -> React.null [@@react.component]
  > EOF
  $ ./pp.exe -impl card.ml
  let __melact_component_1 = Melact_view.Component.make ~name:"Card.make"
  let __melact_template_2 =
    Melact_view.Template.make ~html:"<section><!----></section>"
      ~holes:[|(Melact_view.Template.Text ([], 0));(Melact_view.Template.Child
                                                      ([], 1))|]
  let make ~title:(title as __melact_prop_0) ?size:((size as __melact_prop_1)=
    1) ?subtitle:(subtitle as __melact_prop_2)
    ~children:(children as __melact_prop_3) () =
    React.Element
      (Melact_view.View.component __melact_component_1
         [|(Melact_view.View.Input __melact_prop_0);(Melact_view.View.Input
                                                       __melact_prop_1);(
           Melact_view.View.Input __melact_prop_2);(Melact_view.View.Input
                                                      __melact_prop_3)|]
         (fun () ->
            let React.Element __melact_child =
              React.Element
                (Melact_view.View.guarded __melact_template_2 2
                   (fun __melact_block ->
                      let __melact_changed_0 =
                        Melact_view.View.check __melact_block 0 children in
                      let __melact_changed_1 =
                        Melact_view.View.check __melact_block 1 title in
                      (match __melact_changed_1 with
                       | Melact_view.View.Unchanged -> ()
                       | _ ->
                           Melact_view.View.put __melact_block 0
                             (Melact_view.View.HText (title : string)));
                      (match __melact_changed_0 with
                       | Melact_view.View.Unchanged -> ()
                       | _ ->
                           Melact_view.View.put __melact_block 1
                             (Melact_view.View.HChild
                                (let React.Element __melact_child = children in
                                 __melact_child)));
                      ())) in
            __melact_child))
  let __melact_component_3 = Melact_view.Component.make ~name:"Card.nothing"
  let nothing () =
    React.Element
      (Melact_view.View.component __melact_component_3 [||]
         (fun () ->
            let React.Element __melact_child = React.null in __melact_child))
  $ cat > card.mli <<'EOF'
  > val make : title:string -> ?size:int -> ?subtitle:string -> children:React.element -> React.element
  > [@@react.component]
  > EOF
  $ ./pp.exe -intf card.mli
  val make :
    title:string ->
      ?size:int ->
        ?subtitle:string -> children:React.element -> unit -> React.element

React.forwardRef: the ref becomes an optional prop and reaches the body as reason-react passes it:

  $ cat > fancy.ml <<'EOF'
  > let make = React.forwardRef (fun ~label ref ->
  >   ((input ~placeholder:label ?ref:(Option.map ReactDOM.Ref.domRef (Js.Nullable.toOption ref)) ()) [@JSX]))
  > [@@react.component]
  > EOF
  $ ./pp.exe -impl fancy.ml
  let __melact_component_1 = Melact_view.Component.make ~name:"Fancy.make"
  let __melact_template_2 =
    Melact_view.Template.make ~html:"<input>"
      ~holes:[|(Melact_view.Template.Attr ([], "placeholder"));(Melact_view.Template.Ref
                                                                  [])|]
  let make ~label:(label as __melact_prop_0)
    ?ref:(__melact_forwarded_ref as __melact_prop_1) () =
    React.Element
      (Melact_view.View.component __melact_component_1
         [|(Melact_view.View.Input __melact_prop_0);(Melact_view.View.Input
                                                       __melact_prop_1)|]
         (fun () ->
            let React.Element __melact_child =
              let ref = ReactDOM.Ref.forwarded __melact_forwarded_ref in
              React.Element
                (Melact_view.View.guarded __melact_template_2 1
                   (fun __melact_block ->
                      let __melact_changed_0 =
                        Melact_view.View.check __melact_block 0 label in
                      (match __melact_changed_0 with
                       | Melact_view.View.Unchanged -> ()
                       | _ ->
                           Melact_view.View.put __melact_block 0
                             (Melact_view.View.HAttr (Some (label : string))));
                      Melact_view.View.put __melact_block 1
                        (Melact_view.View.HRef
                           (Option.fold ~none:ignore ~some:ReactDOM.Ref.attach
                              (Option.map ReactDOM.Ref.domRef
                                 (Js.Nullable.toOption ref))));
                      ())) in
            __melact_child))

Calls with children, keys and fragments:

  $ cat > calls.ml <<'EOF'
  > let one = ((Card.createElement ~title:"a" ~children:[ React.string "x" ] ()) [@JSX])
  > let many = ((Card.createElement ~title:"a" ~key:"k" ~children:[ React.string "x"; React.string "y" ] ()) [@JSX])
  > let none = ((Card.make ~title:"a" ~children:[] ()) [@JSX])
  > let rows items = React.array (Array.map (fun item -> ((li ~key:item ~children:[ React.string item ] ()) [@JSX])) items)
  > let both = (([ one; many ]) [@JSX])
  > EOF
  $ ./pp.exe -impl calls.ml
  let one = Card.make ~title:"a" ~children:(React.string "x") ()
  let many =
    React.Element
      (Melact_view.View.with_key ("k" : string)
         (let React.Element __melact_child =
            Card.make ~title:"a"
              ~children:(React.array [|(React.string "x");(React.string "y")|])
              () in
          __melact_child))
  let none = Card.make ~title:"a" ()
  let __melact_template_1 =
    Melact_view.Template.make ~html:"<li></li>"
      ~holes:[|(Melact_view.Template.Text ([], 0))|]
  let rows items =
    React.array
      (Array.map
         (fun item ->
            React.Element
              (Melact_view.View.with_key (item : string)
                 (let React.Element __melact_child =
                    React.Element
                      (Melact_view.View.guarded __melact_template_1 1
                         (fun __melact_block ->
                            let __melact_changed_0 =
                              Melact_view.View.check __melact_block 0 item in
                            (match __melact_changed_0 with
                             | Melact_view.View.Unchanged -> ()
                             | _ ->
                                 Melact_view.View.put __melact_block 0
                                   (Melact_view.View.HText (item : string)));
                            ())) in
                  __melact_child))) items)
  let both =
    React.Element
      (Melact_view.View.list
         [(let React.Element __melact_child = one in __melact_child);
         (let React.Element __melact_child = many in __melact_child)])

Hooks get one key per call site, also inside custom hooks:

  $ cat > hooks.ml <<'EOF'
  > let useToggle () = React.useState (fun () -> false)
  > let make () =
  >   let shown, _ = useToggle () in
  >   React.useEffect1 (fun () -> None) [| shown |];
  >   React.string (React.useContext Theme.context)
  > [@@react.component]
  > EOF
  $ ./pp.exe -impl hooks.ml
  let __melact_hook_1 = Melact_view.Hook.key ()
  let useToggle () = (React.useState __melact_hook_1) (fun () -> false)
  let __melact_component_2 = Melact_view.Component.make ~name:"Hooks.make"
  let __melact_hook_3 = Melact_view.Hook.key ()
  let make () =
    React.Element
      (Melact_view.View.component __melact_component_2 [||]
         (fun () ->
            let React.Element __melact_child =
              let (shown, _) = useToggle () in
              (React.useEffect1 __melact_hook_3) (fun () -> None) [|shown|];
              React.string (React.useContext Theme.context) in
            __melact_child))

Reason input:

  $ cat > greeting.re <<'EOF'
  > [@react.component]
  > let make = (~name) => <span className="greeting"> {React.string("Hello, " ++ name)} </span>;
  > EOF
  $ refmt --print ml greeting.re > greeting.ml
  $ ./pp.exe -impl greeting.ml
  let __melact_component_1 = Melact_view.Component.make ~name:"Greeting.make"
  let __melact_template_2 =
    Melact_view.Template.make ~html:"<span class=\"greeting\"></span>"
      ~holes:[|(Melact_view.Template.Text ([], 0))|]
  let make ~name:(name as __melact_prop_0) () =
    React.Element
      (Melact_view.View.component __melact_component_1
         [|(Melact_view.View.Input __melact_prop_0)|]
         (fun () ->
            let React.Element __melact_child =
              React.Element
                (Melact_view.View.guarded __melact_template_2 1
                   (fun __melact_block ->
                      let __melact_changed_0 =
                        Melact_view.View.check __melact_block 0 name in
                      (match __melact_changed_0 with
                       | Melact_view.View.Unchanged -> ()
                       | _ ->
                           Melact_view.View.put __melact_block 0
                             (Melact_view.View.HText
                                ("Hello, " ^ name : string)));
                      ())) in
            __melact_child))

mlx input:

  $ cat > greeting.mlx <<'EOF'
  > let[@react.component] make ~name =
  >   <span className="greeting">(React.string ("Hello, " ^ name))</span>
  > EOF
  $ mlx-pp greeting.mlx > greeting.ast
  $ ./pp.exe -impl greeting.ast
  let __melact_component_1 = Melact_view.Component.make ~name:"Greeting.make"
  let __melact_template_2 =
    Melact_view.Template.make ~html:"<span class=\"greeting\"></span>"
      ~holes:[|(Melact_view.Template.Text ([], 0))|]
  let make ~name:(name as __melact_prop_0) () =
    React.Element
      (Melact_view.View.component __melact_component_1
         [|(Melact_view.View.Input __melact_prop_0)|]
         (fun () ->
            let React.Element __melact_child =
              React.Element
                (Melact_view.View.guarded __melact_template_2 1
                   (fun __melact_block ->
                      let __melact_changed_0 =
                        Melact_view.View.check __melact_block 0 name in
                      (match __melact_changed_0 with
                       | Melact_view.View.Unchanged -> ()
                       | _ ->
                           Melact_view.View.put __melact_block 0
                             (Melact_view.View.HText
                                ("Hello, " ^ name : string)));
                      ())) in
            __melact_child))

Errors point at the source:

  $ cat > unknown.ml <<'EOF'
  > let x = ((div ~colour:"red" ()) [@JSX])
  > EOF
  $ ./pp.exe -impl unknown.ml
  File "unknown.ml", line 1, characters 22-27:
  1 | let x = ((div ~colour:"red" ()) [@JSX])
                            ^^^^^
  Error: melact: <div> has no prop colour
  [1]
