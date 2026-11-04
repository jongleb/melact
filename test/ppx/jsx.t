A static tree becomes one template and one hoisted element:

  $ cat > static.ml <<'EOF'
  > let header = ((header ~className:"top" ~children:[ ((h1 ~children:[ React.string "Hi & <bye>" ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl static.ml
  let __mehole_template_1 =
    Mehole.Template.make
      ~html:"<header class=\"top\"><h1>Hi &amp; &lt;bye&gt;</h1></header>"
      ~holes:[||]
  let __mehole_element_2 =
    React.Element (Mehole.View.tpl_instance __mehole_template_1 [||])
  let header = __mehole_element_2

Holes at every depth; markers only between neighbours that would merge:

  $ cat > holes.ml <<'EOF'
  > let row ~name ~count ~extra =
  >   ((p ~children:[ React.string "a"; React.string name; React.string "b"; extra; extra;
  >                   ((b ~children:[ React.int count ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl holes.ml
  let __mehole_template_1 =
    Mehole.Template.make ~html:"<p>a<!---->b<!----><b></b></p>"
      ~holes:[|(Mehole.Template.Text ([], 1));(Mehole.Template.Child ([], 3));(
               Mehole.Template.Child ([], 4));(Mehole.Template.Text ([4], 0))|]
  let row ~name ~count ~extra =
    React.Element
      (Mehole.View.guarded __mehole_template_1 3
         (fun __mehole_block ->
            let __mehole_changed_0 = Mehole.View.check __mehole_block 0 count in
            let __mehole_changed_1 = Mehole.View.check __mehole_block 1 extra in
            let __mehole_changed_2 = Mehole.View.check __mehole_block 2 name in
            (match __mehole_changed_2 with
             | Mehole.View.Unchanged -> ()
             | _ ->
                 Mehole.View.put __mehole_block 0
                   (Mehole.View.HText (name : string)));
            (match __mehole_changed_1 with
             | Mehole.View.Unchanged -> ()
             | _ ->
                 Mehole.View.put __mehole_block 1
                   (Mehole.View.HChild
                      (let React.Element __mehole_child = extra in
                       __mehole_child)));
            (match __mehole_changed_1 with
             | Mehole.View.Unchanged -> ()
             | _ ->
                 Mehole.View.put __mehole_block 2
                   (Mehole.View.HChild
                      (let React.Element __mehole_child = extra in
                       __mehole_child)));
            (match __mehole_changed_0 with
             | Mehole.View.Unchanged -> ()
             | _ ->
                 Mehole.View.put __mehole_block 3
                   (Mehole.View.HText (string_of_int (count : int))));
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
  let __mehole_template_1 =
    Mehole.Template.make ~html:"<input id=\"name\" required maxLength=\"3\">"
      ~holes:[|(Mehole.Template.Attr ([], "class"));(Mehole.Template.Attr
                                                       ([], "disabled"));(
               Mehole.Template.Attr ([], "aria-hidden"));(Mehole.Template.Attr
                                                            ([], "tabIndex"));(
               Mehole.Template.Prop ([], "value"));(Mehole.Template.Prop
                                                      ([], "checked"));(
               Mehole.Template.Style []);(Mehole.Template.Ref []);(Mehole.Template.Attr
                                                                     ([],
                                                                      "title"));(
               Mehole.Template.Handler ([], "input"));(Mehole.Template.Handler
                                                         ([], "keydown"))|]
  let __mehole_template_2 =
    Mehole.Template.make ~html:"<div stroke-width=\"2\" for=\"x\"></div>"
      ~holes:[|(Mehole.Template.Prop ([], "innerHTML"))|]
  let form ~text ~flag ~tab ~opacity ~style ~ref ~maybe ~html ~onInput =
    ((React.Element
        (Mehole.View.guarded __mehole_template_1 5
           (fun __mehole_block ->
              let __mehole_changed_0 = Mehole.View.check __mehole_block 0 flag in
              let __mehole_changed_1 = Mehole.View.check __mehole_block 1 maybe in
              let __mehole_changed_2 = Mehole.View.check __mehole_block 2 style in
              let __mehole_changed_3 = Mehole.View.check __mehole_block 3 tab in
              let __mehole_changed_4 = Mehole.View.check __mehole_block 4 text in
              (match __mehole_changed_4 with
               | Mehole.View.Unchanged -> ()
               | _ ->
                   Mehole.View.put __mehole_block 0
                     (Mehole.View.HAttr (Some (text : string))));
              (match __mehole_changed_0 with
               | Mehole.View.Unchanged -> ()
               | _ ->
                   Mehole.View.put __mehole_block 1
                     (Mehole.View.HAttr
                        (if (flag : bool) then Some "" else None)));
              (match __mehole_changed_0 with
               | Mehole.View.Unchanged -> ()
               | _ ->
                   Mehole.View.put __mehole_block 2
                     (Mehole.View.HAttr
                        (Some (if (flag : bool) then "true" else "false"))));
              (match __mehole_changed_3 with
               | Mehole.View.Unchanged -> ()
               | _ ->
                   Mehole.View.put __mehole_block 3
                     (Mehole.View.HAttr (Some (string_of_int (tab : int)))));
              (match __mehole_changed_4 with
               | Mehole.View.Unchanged -> ()
               | _ ->
                   Mehole.View.put __mehole_block 4
                     (Mehole.View.HProp (text : string)));
              (match __mehole_changed_0 with
               | Mehole.View.Unchanged -> ()
               | _ ->
                   Mehole.View.put __mehole_block 5
                     (Mehole.View.HProp (flag : bool)));
              (match __mehole_changed_2 with
               | Mehole.View.Unchanged -> ()
               | _ ->
                   Mehole.View.put __mehole_block 6
                     (Mehole.View.HStyle (ReactDOM.Style.declarations style)));
              Mehole.View.put __mehole_block 7
                (Mehole.View.HRef (ReactDOM.Ref.attach ref));
              (match __mehole_changed_1 with
               | Mehole.View.Unchanged -> ()
               | _ ->
                   Mehole.View.put __mehole_block 8
                     (Mehole.View.HAttr (maybe : string option)));
              Mehole.View.put __mehole_block 9
                (Mehole.View.HHandler
                   (fun __mehole_event ->
                      onInput (ReactEvent.Form.Native __mehole_event)));
              Mehole.View.put __mehole_block 10
                (Mehole.View.HHandler
                   (fun __mehole_event ->
                      Option.iter
                        (fun handle ->
                           handle (ReactEvent.Keyboard.Native __mehole_event))
                        None));
              ()))),
      (React.Element
         (Mehole.View.guarded __mehole_template_2 1
            (fun __mehole_block ->
               let __mehole_changed_0 = Mehole.View.check __mehole_block 0 html in
               (match __mehole_changed_0 with
                | Mehole.View.Unchanged -> ()
                | _ ->
                    Mehole.View.put __mehole_block 0
                      (Mehole.View.HProp (html ## __html)));
               ()))))

A component with optional, defaulted and children props, and its signature:

  $ cat > card.ml <<'EOF'
  > let make ~title ?(size = 1) ?subtitle ~children () =
  >   ((section ~children:[ React.string title; children ] ()) [@JSX])
  > [@@react.component]
  > let nothing = fun () -> React.null [@@react.component]
  > EOF
  $ ./pp.exe -impl card.ml
  let __mehole_component_1 = Mehole.Component.make ~name:"Card.make"
  let __mehole_template_2 =
    Mehole.Template.make ~html:"<section><!----></section>"
      ~holes:[|(Mehole.Template.Text ([], 0));(Mehole.Template.Child ([], 1))|]
  let make ~title:(title as __mehole_prop_0) ?size:((size as __mehole_prop_1)=
    1) ?subtitle:(subtitle as __mehole_prop_2)
    ~children:(children as __mehole_prop_3) () =
    React.Element
      (Mehole.View.component __mehole_component_1
         [|(Mehole.View.Input __mehole_prop_0);(Mehole.View.Input
                                                  __mehole_prop_1);(Mehole.View.Input
                                                                      __mehole_prop_2);(
           Mehole.View.Input __mehole_prop_3)|]
         (fun () ->
            let React.Element __mehole_child =
              React.Element
                (Mehole.View.guarded __mehole_template_2 2
                   (fun __mehole_block ->
                      let __mehole_changed_0 =
                        Mehole.View.check __mehole_block 0 children in
                      let __mehole_changed_1 =
                        Mehole.View.check __mehole_block 1 title in
                      (match __mehole_changed_1 with
                       | Mehole.View.Unchanged -> ()
                       | _ ->
                           Mehole.View.put __mehole_block 0
                             (Mehole.View.HText (title : string)));
                      (match __mehole_changed_0 with
                       | Mehole.View.Unchanged -> ()
                       | _ ->
                           Mehole.View.put __mehole_block 1
                             (Mehole.View.HChild
                                (let React.Element __mehole_child = children in
                                 __mehole_child)));
                      ())) in
            __mehole_child))
  let __mehole_component_3 = Mehole.Component.make ~name:"Card.nothing"
  let nothing () =
    React.Element
      (Mehole.View.component __mehole_component_3 [||]
         (fun () ->
            let React.Element __mehole_child = React.null in __mehole_child))
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
  let __mehole_component_1 = Mehole.Component.make ~name:"Fancy.make"
  let __mehole_template_2 =
    Mehole.Template.make ~html:"<input>"
      ~holes:[|(Mehole.Template.Attr ([], "placeholder"));(Mehole.Template.Ref
                                                             [])|]
  let make ~label:(label as __mehole_prop_0)
    ?ref:(__mehole_forwarded_ref as __mehole_prop_1) () =
    React.Element
      (Mehole.View.component __mehole_component_1
         [|(Mehole.View.Input __mehole_prop_0);(Mehole.View.Input
                                                  __mehole_prop_1)|]
         (fun () ->
            let React.Element __mehole_child =
              let ref = ReactDOM.Ref.forwarded __mehole_forwarded_ref in
              React.Element
                (Mehole.View.guarded __mehole_template_2 1
                   (fun __mehole_block ->
                      let __mehole_changed_0 =
                        Mehole.View.check __mehole_block 0 label in
                      (match __mehole_changed_0 with
                       | Mehole.View.Unchanged -> ()
                       | _ ->
                           Mehole.View.put __mehole_block 0
                             (Mehole.View.HAttr (Some (label : string))));
                      Mehole.View.put __mehole_block 1
                        (Mehole.View.HRef
                           (Option.fold ~none:ignore ~some:ReactDOM.Ref.attach
                              (Option.map ReactDOM.Ref.domRef
                                 (Js.Nullable.toOption ref))));
                      ())) in
            __mehole_child))

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
      (Mehole.View.with_key ("k" : string)
         (let React.Element __mehole_child =
            Card.make ~title:"a"
              ~children:(React.array [|(React.string "x");(React.string "y")|])
              () in
          __mehole_child))
  let none = Card.make ~title:"a" ()
  let __mehole_template_1 =
    Mehole.Template.make ~html:"<li></li>"
      ~holes:[|(Mehole.Template.Text ([], 0))|]
  let rows items =
    React.array
      (Array.map
         (fun item ->
            React.Element
              (Mehole.View.with_key (item : string)
                 (let React.Element __mehole_child =
                    React.Element
                      (Mehole.View.guarded __mehole_template_1 1
                         (fun __mehole_block ->
                            let __mehole_changed_0 =
                              Mehole.View.check __mehole_block 0 item in
                            (match __mehole_changed_0 with
                             | Mehole.View.Unchanged -> ()
                             | _ ->
                                 Mehole.View.put __mehole_block 0
                                   (Mehole.View.HText (item : string)));
                            ())) in
                  __mehole_child))) items)
  let both =
    React.Element
      (Mehole.View.list
         [(let React.Element __mehole_child = one in __mehole_child);
         (let React.Element __mehole_child = many in __mehole_child)])

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
  let __mehole_hook_1 = Mehole.Hook.key ()
  let useToggle () = (React.useState __mehole_hook_1) (fun () -> false)
  let __mehole_component_2 = Mehole.Component.make ~name:"Hooks.make"
  let __mehole_hook_3 = Mehole.Hook.key ()
  let make () =
    React.Element
      (Mehole.View.component __mehole_component_2 [||]
         (fun () ->
            let React.Element __mehole_child =
              let (shown, _) = useToggle () in
              (React.useEffect1 __mehole_hook_3) (fun () -> None) [|shown|];
              React.string (React.useContext Theme.context) in
            __mehole_child))

Reason input:

  $ cat > greeting.re <<'EOF'
  > [@react.component]
  > let make = (~name) => <span className="greeting"> {React.string("Hello, " ++ name)} </span>;
  > EOF
  $ refmt --print ml greeting.re > greeting.ml
  $ ./pp.exe -impl greeting.ml
  let __mehole_component_1 = Mehole.Component.make ~name:"Greeting.make"
  let __mehole_template_2 =
    Mehole.Template.make ~html:"<span class=\"greeting\"></span>"
      ~holes:[|(Mehole.Template.Text ([], 0))|]
  let make ~name:(name as __mehole_prop_0) () =
    React.Element
      (Mehole.View.component __mehole_component_1
         [|(Mehole.View.Input __mehole_prop_0)|]
         (fun () ->
            let React.Element __mehole_child =
              React.Element
                (Mehole.View.guarded __mehole_template_2 1
                   (fun __mehole_block ->
                      let __mehole_changed_0 =
                        Mehole.View.check __mehole_block 0 name in
                      (match __mehole_changed_0 with
                       | Mehole.View.Unchanged -> ()
                       | _ ->
                           Mehole.View.put __mehole_block 0
                             (Mehole.View.HText ("Hello, " ^ name : string)));
                      ())) in
            __mehole_child))

mlx input:

  $ cat > greeting.mlx <<'EOF'
  > let[@react.component] make ~name =
  >   <span className="greeting">(React.string ("Hello, " ^ name))</span>
  > EOF
  $ mlx-pp greeting.mlx > greeting.ast
  $ ./pp.exe -impl greeting.ast
  let __mehole_component_1 = Mehole.Component.make ~name:"Greeting.make"
  let __mehole_template_2 =
    Mehole.Template.make ~html:"<span class=\"greeting\"></span>"
      ~holes:[|(Mehole.Template.Text ([], 0))|]
  let make ~name:(name as __mehole_prop_0) () =
    React.Element
      (Mehole.View.component __mehole_component_1
         [|(Mehole.View.Input __mehole_prop_0)|]
         (fun () ->
            let React.Element __mehole_child =
              React.Element
                (Mehole.View.guarded __mehole_template_2 1
                   (fun __mehole_block ->
                      let __mehole_changed_0 =
                        Mehole.View.check __mehole_block 0 name in
                      (match __mehole_changed_0 with
                       | Mehole.View.Unchanged -> ()
                       | _ ->
                           Mehole.View.put __mehole_block 0
                             (Mehole.View.HText ("Hello, " ^ name : string)));
                      ())) in
            __mehole_child))

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
