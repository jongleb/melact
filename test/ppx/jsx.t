A static tree becomes one template and one hoisted element:

  $ cat > static.ml <<'EOF'
  > let header = ((header ~className:"top" ~children:[ ((h1 ~children:[ React.string "Hi & <bye>" ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl static.ml
  let __melhole_element_1 =
    React.Element
      (Melhole.View.static
         (Melhole.Template.html
            "<header class=\"top\"><h1>Hi &amp; &lt;bye&gt;</h1></header>"))
  let header = __melhole_element_1

Holes at every depth; markers only between neighbours that would merge:

  $ cat > holes.ml <<'EOF'
  > let row ~name ~count ~extra =
  >   ((p ~children:[ React.string "a"; React.string name; React.string "b"; extra; extra;
  >                   ((b ~children:[ React.int count ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl holes.ml
  let __melhole_template_1 =
    Melhole.View.template
      (Melhole.Template.html "<p>a<!---->b<!----><b></b></p>")
      (fun __melhole_scope __melhole_node ->
         let __melhole_node_0 = Melhole.Template.first __melhole_node in
         let __melhole_node_1 = Melhole.Template.next __melhole_node_0 in
         let __melhole_node_2 = Melhole.Template.next __melhole_node_1 in
         let __melhole_node_3 = Melhole.Template.next __melhole_node_2 in
         let __melhole_node_4 = Melhole.Template.next __melhole_node_3 in
         ((Melhole.View.text_hole
             {
               Melhole.Template.parent = __melhole_node;
               before = (Melhole.Template.next_or_end __melhole_node_0)
             }),
           (Melhole.View.content_hole __melhole_scope
              {
                Melhole.Template.parent = __melhole_node;
                before = (Melhole.Template.next_or_end __melhole_node_2)
              }),
           (Melhole.View.content_hole __melhole_scope
              {
                Melhole.Template.parent = __melhole_node;
                before = (Melhole.Template.next_or_end __melhole_node_3)
              }),
           (Melhole.View.text_hole
              {
                Melhole.Template.parent = __melhole_node_4;
                before = (Melhole.Template.first_or_end __melhole_node_4)
              })))
  let row ~name ~count ~extra =
    React.Element
      (Melhole.View.compiled __melhole_template_1 3
         (fun __melhole_scope
            (__melhole_hole_0, __melhole_hole_1, __melhole_hole_2,
             __melhole_hole_3)
            ->
            let __melhole_changed_0 =
              Melhole.View.check __melhole_scope 0 count in
            let __melhole_changed_1 =
              Melhole.View.check __melhole_scope 1 extra in
            let __melhole_changed_2 = Melhole.View.check __melhole_scope 2 name in
            (match __melhole_changed_2 with
             | Melhole.View.Unchanged -> ()
             | _ -> Melhole.View.set_text __melhole_hole_0 (name : string));
            (match __melhole_changed_1 with
             | Melhole.View.Unchanged -> ()
             | _ ->
                 Melhole.View.set_content __melhole_hole_1
                   (let React.Element __melhole_child = extra in
                    __melhole_child));
            (match __melhole_changed_1 with
             | Melhole.View.Unchanged -> ()
             | _ ->
                 Melhole.View.set_content __melhole_hole_2
                   (let React.Element __melhole_child = extra in
                    __melhole_child));
            (match __melhole_changed_0 with
             | Melhole.View.Unchanged -> ()
             | _ ->
                 Melhole.View.set_text __melhole_hole_3
                   (string_of_int (count : int)));
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
  let __melhole_template_1 =
    Melhole.View.template
      (Melhole.Template.html "<input id=\"name\" required maxLength=\"3\">")
      (fun __melhole_scope __melhole_node ->
         ((Melhole.View.attr_hole (Melhole.Template.element __melhole_node)
             "class"),
           (Melhole.View.attr_hole (Melhole.Template.element __melhole_node)
              "disabled"),
           (Melhole.View.attr_hole (Melhole.Template.element __melhole_node)
              "aria-hidden"),
           (Melhole.View.attr_hole (Melhole.Template.element __melhole_node)
              "tabIndex"),
           (Melhole.View.prop_hole (Melhole.Template.element __melhole_node)
              "value"),
           (Melhole.View.prop_hole (Melhole.Template.element __melhole_node)
              "checked"),
           (Melhole.View.style_hole (Melhole.Template.element __melhole_node)),
           (Melhole.View.reference_hole __melhole_scope
              (Melhole.Template.element __melhole_node)),
           (Melhole.View.attr_hole (Melhole.Template.element __melhole_node)
              "title"),
           (Melhole.View.handler_hole __melhole_scope
              (Melhole.Template.element __melhole_node) "input"),
           (Melhole.View.handler_hole __melhole_scope
              (Melhole.Template.element __melhole_node) "keydown")))
  let __melhole_template_2 =
    Melhole.View.template
      (Melhole.Template.html "<div stroke-width=\"2\" for=\"x\"></div>")
      (fun __melhole_scope __melhole_node ->
         Melhole.View.prop_hole (Melhole.Template.element __melhole_node)
           "innerHTML")
  let form ~text ~flag ~tab ~opacity ~style ~ref ~maybe ~html ~onInput =
    ((React.Element
        (Melhole.View.compiled __melhole_template_1 5
           (fun __melhole_scope
              (__melhole_hole_0, __melhole_hole_1, __melhole_hole_2,
               __melhole_hole_3, __melhole_hole_4, __melhole_hole_5,
               __melhole_hole_6, __melhole_hole_7, __melhole_hole_8,
               __melhole_hole_9, __melhole_hole_10)
              ->
              let __melhole_changed_0 =
                Melhole.View.check __melhole_scope 0 flag in
              let __melhole_changed_1 =
                Melhole.View.check __melhole_scope 1 maybe in
              let __melhole_changed_2 =
                Melhole.View.check __melhole_scope 2 style in
              let __melhole_changed_3 =
                Melhole.View.check __melhole_scope 3 tab in
              let __melhole_changed_4 =
                Melhole.View.check __melhole_scope 4 text in
              (match __melhole_changed_4 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.set_attr __melhole_hole_0
                     (Some (text : string)));
              (match __melhole_changed_0 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.set_attr __melhole_hole_1
                     (if (flag : bool) then Some "" else None));
              (match __melhole_changed_0 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.set_attr __melhole_hole_2
                     (Some (if (flag : bool) then "true" else "false")));
              (match __melhole_changed_3 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.set_attr __melhole_hole_3
                     (Some (string_of_int (tab : int))));
              (match __melhole_changed_4 with
               | Melhole.View.Unchanged -> ()
               | _ -> Melhole.View.set_prop __melhole_hole_4 (text : string));
              (match __melhole_changed_0 with
               | Melhole.View.Unchanged -> ()
               | _ -> Melhole.View.set_prop __melhole_hole_5 (flag : bool));
              (match __melhole_changed_2 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.set_style __melhole_hole_6
                     (ReactDOM.Style.declarations style));
              Melhole.View.set_reference __melhole_hole_7
                (ReactDOM.Ref.attach ref);
              (match __melhole_changed_1 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.set_attr __melhole_hole_8
                     (maybe : string option));
              Melhole.View.set_handler __melhole_hole_9
                (fun __melhole_event ->
                   onInput (ReactEvent.Form.Native __melhole_event));
              Melhole.View.set_handler __melhole_hole_10
                (fun __melhole_event ->
                   Option.iter
                     (fun handle ->
                        handle (ReactEvent.Keyboard.Native __melhole_event))
                     None);
              ()))),
      (React.Element
         (Melhole.View.compiled __melhole_template_2 1
            (fun __melhole_scope __melhole_hole_0 ->
               let __melhole_changed_0 =
                 Melhole.View.check __melhole_scope 0 html in
               (match __melhole_changed_0 with
                | Melhole.View.Unchanged -> ()
                | _ -> Melhole.View.set_prop __melhole_hole_0 (html ## __html));
               ()))))

A component with optional, defaulted and children props, and its signature:

  $ cat > card.ml <<'EOF'
  > let make ~title ?(size = 1) ?subtitle ~children () =
  >   ((section ~children:[ React.string title; children ] ()) [@JSX])
  > [@@react.component]
  > let nothing = fun () -> React.null [@@react.component]
  > EOF
  $ ./pp.exe -impl card.ml
  let __melhole_component_1 = Melhole.Component.make ~name:"Card.make"
  let __melhole_template_2 =
    Melhole.View.template (Melhole.Template.html "<section><!----></section>")
      (fun __melhole_scope __melhole_node ->
         let __melhole_node_0 = Melhole.Template.first __melhole_node in
         ((Melhole.View.text_hole
             {
               Melhole.Template.parent = __melhole_node;
               before = (Melhole.Template.first_or_end __melhole_node)
             }),
           (Melhole.View.content_hole __melhole_scope
              {
                Melhole.Template.parent = __melhole_node;
                before = (Melhole.Template.next_or_end __melhole_node_0)
              })))
  let make ~title:(title as __melhole_prop_0)
    ?size:((size as __melhole_prop_1)= 1)
    ?subtitle:(subtitle as __melhole_prop_2)
    ~children:(children as __melhole_prop_3) () =
    React.Element
      (Melhole.View.component __melhole_component_1
         [|(Melhole.View.Input __melhole_prop_0);(Melhole.View.Input
                                                    __melhole_prop_1);(
           Melhole.View.Input __melhole_prop_2);(Melhole.View.Input
                                                   __melhole_prop_3)|]
         (fun () ->
            let React.Element __melhole_child =
              React.Element
                (Melhole.View.compiled __melhole_template_2 2
                   (fun __melhole_scope (__melhole_hole_0, __melhole_hole_1) ->
                      let __melhole_changed_0 =
                        Melhole.View.check __melhole_scope 0 children in
                      let __melhole_changed_1 =
                        Melhole.View.check __melhole_scope 1 title in
                      (match __melhole_changed_1 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.set_text __melhole_hole_0
                             (title : string));
                      (match __melhole_changed_0 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.set_content __melhole_hole_1
                             (let React.Element __melhole_child = children in
                              __melhole_child));
                      ())) in
            __melhole_child))
  let __melhole_component_3 = Melhole.Component.make ~name:"Card.nothing"
  let nothing () =
    React.Element
      (Melhole.View.component __melhole_component_3 [||]
         (fun () ->
            let React.Element __melhole_child = React.null in __melhole_child))
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
  let __melhole_component_1 = Melhole.Component.make ~name:"Fancy.make"
  let __melhole_template_2 =
    Melhole.View.template (Melhole.Template.html "<input>")
      (fun __melhole_scope __melhole_node ->
         ((Melhole.View.attr_hole (Melhole.Template.element __melhole_node)
             "placeholder"),
           (Melhole.View.reference_hole __melhole_scope
              (Melhole.Template.element __melhole_node))))
  let make ~label:(label as __melhole_prop_0)
    ?ref:(__melhole_forwarded_ref as __melhole_prop_1) () =
    React.Element
      (Melhole.View.component __melhole_component_1
         [|(Melhole.View.Input __melhole_prop_0);(Melhole.View.Input
                                                    __melhole_prop_1)|]
         (fun () ->
            let React.Element __melhole_child =
              let ref = ReactDOM.Ref.forwarded __melhole_forwarded_ref in
              React.Element
                (Melhole.View.compiled __melhole_template_2 1
                   (fun __melhole_scope (__melhole_hole_0, __melhole_hole_1) ->
                      let __melhole_changed_0 =
                        Melhole.View.check __melhole_scope 0 label in
                      (match __melhole_changed_0 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.set_attr __melhole_hole_0
                             (Some (label : string)));
                      Melhole.View.set_reference __melhole_hole_1
                        (Option.fold ~none:ignore ~some:ReactDOM.Ref.attach
                           (Option.map ReactDOM.Ref.domRef
                              (Js.Nullable.toOption ref)));
                      ())) in
            __melhole_child))

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
      (Melhole.View.with_key ("k" : string)
         (let React.Element __melhole_child =
            Card.make ~title:"a"
              ~children:(React.array [|(React.string "x");(React.string "y")|])
              () in
          __melhole_child))
  let none = Card.make ~title:"a" ()
  let __melhole_template_1 =
    Melhole.View.template (Melhole.Template.html "<li></li>")
      (fun __melhole_scope __melhole_node ->
         Melhole.View.text_hole
           {
             Melhole.Template.parent = __melhole_node;
             before = (Melhole.Template.first_or_end __melhole_node)
           })
  let rows items =
    React.array
      (Array.map
         (fun item ->
            React.Element
              (Melhole.View.with_key (item : string)
                 (let React.Element __melhole_child =
                    React.Element
                      (Melhole.View.compiled __melhole_template_1 1
                         (fun __melhole_scope __melhole_hole_0 ->
                            let __melhole_changed_0 =
                              Melhole.View.check __melhole_scope 0 item in
                            (match __melhole_changed_0 with
                             | Melhole.View.Unchanged -> ()
                             | _ ->
                                 Melhole.View.set_text __melhole_hole_0
                                   (item : string));
                            ())) in
                  __melhole_child))) items)
  let both =
    React.Element
      (Melhole.View.list
         [(let React.Element __melhole_child = one in __melhole_child);
         (let React.Element __melhole_child = many in __melhole_child)])

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
  let __melhole_hook_1 = Melhole.Hook.key ()
  let useToggle () = (React.useState __melhole_hook_1) (fun () -> false)
  let __melhole_component_2 = Melhole.Component.make ~name:"Hooks.make"
  let __melhole_hook_3 = Melhole.Hook.key ()
  let make () =
    React.Element
      (Melhole.View.component __melhole_component_2 [||]
         (fun () ->
            let React.Element __melhole_child =
              let (shown, _) = useToggle () in
              (React.useEffect1 __melhole_hook_3) (fun () -> None) [|shown|];
              React.string (React.useContext Theme.context) in
            __melhole_child))

Reason input:

  $ cat > greeting.re <<'EOF'
  > [@react.component]
  > let make = (~name) => <span className="greeting"> {React.string("Hello, " ++ name)} </span>;
  > EOF
  $ refmt --print ml greeting.re > greeting.ml
  $ ./pp.exe -impl greeting.ml
  let __melhole_component_1 = Melhole.Component.make ~name:"Greeting.make"
  let __melhole_template_2 =
    Melhole.View.template
      (Melhole.Template.html "<span class=\"greeting\"></span>")
      (fun __melhole_scope __melhole_node ->
         Melhole.View.text_hole
           {
             Melhole.Template.parent = __melhole_node;
             before = (Melhole.Template.first_or_end __melhole_node)
           })
  let make ~name:(name as __melhole_prop_0) () =
    React.Element
      (Melhole.View.component __melhole_component_1
         [|(Melhole.View.Input __melhole_prop_0)|]
         (fun () ->
            let React.Element __melhole_child =
              React.Element
                (Melhole.View.compiled __melhole_template_2 1
                   (fun __melhole_scope __melhole_hole_0 ->
                      let __melhole_changed_0 =
                        Melhole.View.check __melhole_scope 0 name in
                      (match __melhole_changed_0 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.set_text __melhole_hole_0
                             ("Hello, " ^ name : string));
                      ())) in
            __melhole_child))

mlx input:

  $ cat > greeting.mlx <<'EOF'
  > let[@react.component] make ~name =
  >   <span className="greeting">(React.string ("Hello, " ^ name))</span>
  > EOF
  $ mlx-pp greeting.mlx > greeting.ast
  $ ./pp.exe -impl greeting.ast
  let __melhole_component_1 = Melhole.Component.make ~name:"Greeting.make"
  let __melhole_template_2 =
    Melhole.View.template
      (Melhole.Template.html "<span class=\"greeting\"></span>")
      (fun __melhole_scope __melhole_node ->
         Melhole.View.text_hole
           {
             Melhole.Template.parent = __melhole_node;
             before = (Melhole.Template.first_or_end __melhole_node)
           })
  let make ~name:(name as __melhole_prop_0) () =
    React.Element
      (Melhole.View.component __melhole_component_1
         [|(Melhole.View.Input __melhole_prop_0)|]
         (fun () ->
            let React.Element __melhole_child =
              React.Element
                (Melhole.View.compiled __melhole_template_2 1
                   (fun __melhole_scope __melhole_hole_0 ->
                      let __melhole_changed_0 =
                        Melhole.View.check __melhole_scope 0 name in
                      (match __melhole_changed_0 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.set_text __melhole_hole_0
                             ("Hello, " ^ name : string));
                      ())) in
            __melhole_child))

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
