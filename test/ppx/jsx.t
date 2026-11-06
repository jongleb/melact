A static tree becomes one template and one hoisted element:

  $ cat > static.ml <<'EOF'
  > let header = ((header ~className:"top" ~children:[ ((h1 ~children:[ React.string "Hi & <bye>" ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl static.ml
  [@@@alert "-hook"]
  let __melhole_static_1 =
    Melhole.View.static
      (Melhole.Template.html
         "<header class=\"top\"><h1>Hi &amp; &lt;bye&gt;</h1></header>")
  let __melhole_element_2 = React.of_child __melhole_static_1
  let header = __melhole_element_2

Holes at every depth; markers only between neighbours that would merge:

  $ cat > holes.ml <<'EOF'
  > let row ~name ~count ~extra =
  >   ((p ~children:[ React.string "a"; React.string name; React.string "b"; extra; extra;
  >                   ((b ~children:[ React.int count ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl holes.ml
  [@@@alert "-hook"]
  let __melhole_template_1 =
    Melhole.View.template
      (Melhole.Template.html "<p>a<!---->b<!----><b></b></p>")
      {
        Js.Fn.I2 =
          (fun __melhole_scope __melhole_node ->
             let __melhole_node_0 = Melhole.Template.first __melhole_node in
             let __melhole_node_1 = Melhole.Template.next __melhole_node_0 in
             let __melhole_node_2 = Melhole.Template.next __melhole_node_1 in
             let __melhole_node_3 = Melhole.Template.next __melhole_node_2 in
             let __melhole_node_4 = Melhole.Template.next __melhole_node_3 in
             ((Melhole.View.text_at
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
                  }), (Melhole.Template.element __melhole_node_4)))
      }
  let row ~name ~count ~extra =
    React.of_child
      (Melhole.View.compiled __melhole_template_1 5
         {
           Js.Fn.I2 =
             (fun __melhole_scope
                (__melhole_hole_0, __melhole_hole_1, __melhole_hole_2,
                 __melhole_hole_3)
                ->
                let __melhole_changed_0 =
                  Melhole.View.check __melhole_scope 0 count in
                let __melhole_changed_1 =
                  Melhole.View.check __melhole_scope 1 extra in
                let __melhole_changed_2 =
                  Melhole.View.check __melhole_scope 2 name in
                (match __melhole_changed_2 with
                 | Melhole.View.Unchanged -> ()
                 | _ ->
                     Melhole.View.put_text __melhole_scope 3 __melhole_hole_0
                       (name : string));
                (match __melhole_changed_1 with
                 | Melhole.View.Unchanged -> ()
                 | _ ->
                     Melhole.View.set_content __melhole_hole_1
                       (React.to_child extra));
                (match __melhole_changed_1 with
                 | Melhole.View.Unchanged -> ()
                 | _ ->
                     Melhole.View.set_content __melhole_hole_2
                       (React.to_child extra));
                (match __melhole_changed_0 with
                 | Melhole.View.Unchanged -> ()
                 | _ ->
                     Melhole.View.put_sole_text __melhole_scope 4
                       __melhole_hole_3 (string_of_int (count : int)));
                ())
         })

Every kind of prop, static and dynamic, required and optional:

  $ cat > props.ml <<'EOF'
  > let form ~text ~flag ~tab ~opacity ~style ~ref ~maybe ~html ~onInput =
  >   ((input ~className:text ~id:"name" ~disabled:flag ~required:true ~readOnly:false
  >      ~ariaHidden:flag ~tabIndex:tab ~maxLength:3 ~value:text ~checked:flag
  >      ~style ~ref ?title:maybe ~onChange:onInput ?onKeyDown:None ()) [@JSX]),
  >   ((div ~dangerouslySetInnerHTML:html ~strokeWidth:"2" ~htmlFor:"x" ()) [@JSX])
  > EOF
  $ ./pp.exe -impl props.ml
  [@@@alert "-hook"]
  let __melhole_template_1 =
    Melhole.View.template
      (Melhole.Template.html "<input id=\"name\" required maxLength=\"3\">")
      {
        Js.Fn.I2 =
          (fun __melhole_scope __melhole_node ->
             ((Melhole.Template.element __melhole_node),
               (Melhole.Template.element __melhole_node),
               (Melhole.Template.element __melhole_node),
               (Melhole.Template.element __melhole_node),
               (Melhole.View.controlled_hole
                  (Melhole.Template.element __melhole_node) "value"),
               (Melhole.View.controlled_hole
                  (Melhole.Template.element __melhole_node) "checked"),
               (Melhole.View.style_hole
                  (Melhole.Template.element __melhole_node)),
               (Melhole.View.reference_hole __melhole_scope
                  (Melhole.Template.element __melhole_node)),
               (Melhole.Template.element __melhole_node),
               (Melhole.Template.element __melhole_node),
               (Melhole.View.listen __melhole_scope
                  (Melhole.Template.element __melhole_node) "input"),
               (Melhole.Template.element __melhole_node),
               (Melhole.View.listen __melhole_scope
                  (Melhole.Template.element __melhole_node) "keydown")))
      }
  let __melhole_template_2 =
    Melhole.View.template
      (Melhole.Template.html "<div stroke-width=\"2\" for=\"x\"></div>")
      {
        Js.Fn.I2 =
          (fun __melhole_scope __melhole_node ->
             Melhole.View.prop_hole (Melhole.Template.element __melhole_node)
               "innerHTML")
      }
  let form ~text ~flag ~tab ~opacity ~style ~ref ~maybe ~html ~onInput =
    ((React.of_child
        (Melhole.View.compiled __melhole_template_1 12
           {
             Js.Fn.I2 =
               (fun __melhole_scope
                  (__melhole_hole_0, __melhole_hole_1, __melhole_hole_2,
                   __melhole_hole_3, __melhole_hole_4, __melhole_hole_5,
                   __melhole_hole_6, __melhole_hole_7, __melhole_hole_8,
                   __melhole_hole_9, __melhole_key_9, __melhole_hole_10,
                   __melhole_key_10)
                  ->
                  let __melhole_changed_0 =
                    Melhole.View.check __melhole_scope 0 flag in
                  let __melhole_changed_1 =
                    Melhole.View.check __melhole_scope 1 maybe in
                  let __melhole_changed_2 =
                    Melhole.View.check __melhole_scope 2 onInput in
                  let __melhole_changed_3 =
                    Melhole.View.check __melhole_scope 3 style in
                  let __melhole_changed_4 =
                    Melhole.View.check __melhole_scope 4 tab in
                  let __melhole_changed_5 =
                    Melhole.View.check __melhole_scope 5 text in
                  let __melhole_changed_6 =
                    Melhole.View.check __melhole_scope 6 () in
                  (match __melhole_changed_5 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.put_attr __melhole_scope 7 __melhole_hole_0
                         "class" (Some (text : string)));
                  (match __melhole_changed_0 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.put_attr __melhole_scope 8 __melhole_hole_1
                         "disabled" (if (flag : bool) then Some "" else None));
                  (match __melhole_changed_0 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.put_attr __melhole_scope 9 __melhole_hole_2
                         "aria-hidden"
                         (Some (if (flag : bool) then "true" else "false")));
                  (match __melhole_changed_4 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.put_attr __melhole_scope 10
                         __melhole_hole_3 "tabIndex"
                         (Some (string_of_int (tab : int))));
                  (match __melhole_changed_5 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.set_prop __melhole_hole_4 (text : string));
                  (match __melhole_changed_0 with
                   | Melhole.View.Unchanged -> ()
                   | _ -> Melhole.View.set_prop __melhole_hole_5 (flag : bool));
                  (match __melhole_changed_3 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.set_style __melhole_hole_6
                         (ReactDOM.Style.declarations style));
                  Melhole.View.set_reference __melhole_hole_7
                    (ReactDOM.Ref.attach ref);
                  (match __melhole_changed_1 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.put_attr __melhole_scope 11
                         __melhole_hole_8 "title" (maybe : string option));
                  (match __melhole_changed_2 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.put_handler __melhole_hole_9
                         __melhole_key_9
                         (fun __melhole_event ->
                            onInput (React.Event.ofNative __melhole_event)));
                  (match __melhole_changed_6 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.put_handler __melhole_hole_10
                         __melhole_key_10
                         (fun __melhole_event ->
                            Option.iter
                              (fun handle ->
                                 handle (React.Event.ofNative __melhole_event))
                              None));
                  ())
           })),
      (React.of_child
         (Melhole.View.compiled __melhole_template_2 1
            {
              Js.Fn.I2 =
                (fun __melhole_scope __melhole_hole_0 ->
                   let __melhole_changed_0 =
                     Melhole.View.check __melhole_scope 0 html in
                   (match __melhole_changed_0 with
                    | Melhole.View.Unchanged -> ()
                    | _ ->
                        Melhole.View.set_prop __melhole_hole_0 (html ## __html));
                   ())
            })))

A component with optional, defaulted and children props, and its signature:

  $ cat > card.ml <<'EOF'
  > let make ~title ?(size = 1) ?subtitle ~children () =
  >   ((section ~children:[ React.string title; children ] ()) [@JSX])
  > [@@react.component]
  > let nothing = fun () -> React.null [@@react.component]
  > EOF
  $ ./pp.exe -impl card.ml
  [@@@alert "-hook"]
  let __melhole_component_1 = Melact_runtime.Component.make ~name:"Card.make"
  include
    struct
      type props =
        | Props of React.element [@@unboxed ]
      let __melhole_template_2 =
        Melhole.View.template
          (Melhole.Template.html "<section><!----></section>")
          {
            Js.Fn.I2 =
              (fun __melhole_scope __melhole_node ->
                 let __melhole_node_0 = Melhole.Template.first __melhole_node in
                 ((Melhole.View.text_at
                     {
                       Melhole.Template.parent = __melhole_node;
                       before = (Melhole.Template.first_or_end __melhole_node)
                     }),
                   (Melhole.View.content_hole __melhole_scope
                      {
                        Melhole.Template.parent = __melhole_node;
                        before =
                          (Melhole.Template.next_or_end __melhole_node_0)
                      })))
          }
      let makeProps ~title:(title as __melhole_prop_0)
        ?size:((size as __melhole_prop_1)= 1)
        ?subtitle:(subtitle as __melhole_prop_2)
        ~children:(children as __melhole_prop_3) ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_1
               [|(Melhole.View.Input __melhole_prop_0);(Melhole.View.Input
                                                          __melhole_prop_1);(
                 Melhole.View.Input __melhole_prop_2);(Melhole.View.Input
                                                         __melhole_prop_3)|]
               (fun () ->
                  React.to_child
                    (React.of_child
                       (Melhole.View.compiled __melhole_template_2 3
                          {
                            Js.Fn.I2 =
                              (fun __melhole_scope
                                 (__melhole_hole_0, __melhole_hole_1) ->
                                 let __melhole_changed_0 =
                                   Melhole.View.check __melhole_scope 0
                                     children in
                                 let __melhole_changed_1 =
                                   Melhole.View.check __melhole_scope 1 title in
                                 (match __melhole_changed_1 with
                                  | Melhole.View.Unchanged -> ()
                                  | _ ->
                                      Melhole.View.put_text __melhole_scope 2
                                        __melhole_hole_0 (title : string));
                                 (match __melhole_changed_0 with
                                  | Melhole.View.Unchanged -> ()
                                  | _ ->
                                      Melhole.View.set_content __melhole_hole_1
                                        (React.to_child children));
                                 ())
                          })))) in
        Props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : props -> React.element = "%identity"
    end
  let __melhole_component_3 =
    Melact_runtime.Component.make ~name:"Card.nothing"
  include
    struct
      type nothing_props =
        | Nothing_props of React.element [@@unboxed ]
      let nothingProps ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_3 [||]
               (fun () -> React.to_child React.null)) in
        Nothing_props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external nothing : nothing_props -> React.element = "%identity"
    end
  $ cat > card.mli <<'EOF'
  > val make : title:string -> ?size:int -> ?subtitle:string -> children:React.element -> React.element
  > [@@react.component]
  > EOF
  $ ./pp.exe -intf card.mli
  type props
  val makeProps :
    title:string ->
      ?size:int ->
        ?subtitle:string ->
          children:React.element -> ?key:string -> unit -> props
  external make : props -> React.element = "%identity"

React.forwardRef: the ref becomes an optional prop and reaches the body as reason-react passes it:

  $ cat > fancy.ml <<'EOF'
  > let make = React.forwardRef (fun ~label ref ->
  >   ((input ~placeholder:label ?ref:(Option.map ReactDOM.Ref.domRef (Js.Nullable.toOption ref)) ()) [@JSX]))
  > [@@react.component]
  > EOF
  $ ./pp.exe -impl fancy.ml
  [@@@alert "-hook"]
  let __melhole_component_1 = Melact_runtime.Component.make ~name:"Fancy.make"
  include
    struct
      type props =
        | Props of React.element [@@unboxed ]
      let __melhole_template_2 =
        Melhole.View.template (Melhole.Template.html "<input>")
          {
            Js.Fn.I2 =
              (fun __melhole_scope __melhole_node ->
                 ((Melhole.Template.element __melhole_node),
                   (Melhole.View.reference_hole __melhole_scope
                      (Melhole.Template.element __melhole_node))))
          }
      let makeProps ~label:(label as __melhole_prop_0)
        ?ref:(__melhole_forwarded_ref as __melhole_prop_1) ?key:__melhole_key
        () =
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_1
               [|(Melhole.View.Input __melhole_prop_0);(Melhole.View.Input
                                                          __melhole_prop_1)|]
               (fun () ->
                  React.to_child
                    (let ref = ReactDOM.Ref.forwarded __melhole_forwarded_ref in
                     React.of_child
                       (Melhole.View.compiled __melhole_template_2 2
                          {
                            Js.Fn.I2 =
                              (fun __melhole_scope
                                 (__melhole_hole_0, __melhole_hole_1) ->
                                 let __melhole_changed_0 =
                                   Melhole.View.check __melhole_scope 0 label in
                                 (match __melhole_changed_0 with
                                  | Melhole.View.Unchanged -> ()
                                  | _ ->
                                      Melhole.View.put_attr __melhole_scope 1
                                        __melhole_hole_0 "placeholder"
                                        (Some (label : string)));
                                 Melhole.View.set_reference __melhole_hole_1
                                   (Option.fold ~none:ignore
                                      ~some:ReactDOM.Ref.attach
                                      (Option.map ReactDOM.Ref.domRef
                                         (Js.Nullable.toOption ref)));
                                 ())
                          })))) in
        Props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : props -> React.element = "%identity"
    end

Calls with children, keys and fragments:

  $ cat > calls.ml <<'EOF'
  > let one = ((Card.createElement ~title:"a" ~children:[ React.string "x" ] ()) [@JSX])
  > let many = ((Card.createElement ~title:"a" ~key:"k" ~children:[ React.string "x"; React.string "y" ] ()) [@JSX])
  > let none = ((Card.make ~title:"a" ~children:[] ()) [@JSX])
  > let rows items = React.array (Array.map (fun item -> ((li ~key:item ~children:[ React.string item ] ()) [@JSX])) items)
  > let both = (([ one; many ]) [@JSX])
  > EOF
  $ ./pp.exe -impl calls.ml
  [@@@alert "-hook"]
  let one =
    Card.make (Card.makeProps ~title:"a" ~children:(React.string "x") ())
  let many =
    React.of_child
      (Melhole.View.with_key ("k" : string)
         (React.to_child
            (Card.make
               (Card.makeProps ~title:"a"
                  ~children:(React.array
                               [|(React.string "x");(React.string "y")|]) ()))))
  let none = Card.make (Card.makeProps ~title:"a" ())
  let __melhole_template_1 =
    Melhole.View.template (Melhole.Template.html "<li></li>")
      {
        Js.Fn.I2 =
          (fun __melhole_scope __melhole_node ->
             Melhole.Template.element __melhole_node)
      }
  let rows items =
    React.array
      (Array.map
         (fun item ->
            React.of_child
              (Melhole.View.with_key (item : string)
                 (React.to_child
                    (React.of_child
                       (Melhole.View.compiled __melhole_template_1 2
                          {
                            Js.Fn.I2 =
                              (fun __melhole_scope __melhole_hole_0 ->
                                 let __melhole_changed_0 =
                                   Melhole.View.check __melhole_scope 0 item in
                                 (match __melhole_changed_0 with
                                  | Melhole.View.Unchanged -> ()
                                  | _ ->
                                      Melhole.View.put_sole_text
                                        __melhole_scope 1 __melhole_hole_0
                                        (item : string));
                                 ())
                          }))))) items)
  let both =
    React.of_child
      (Melhole.View.list [React.to_child one; React.to_child many])

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
  [@@@alert "-hook"]
  let __melhole_hook_1 = Melact_runtime.Hook.key ()
  let useToggle () = (React.useState __melhole_hook_1) (fun () -> false)
  let __melhole_component_2 = Melact_runtime.Component.make ~name:"Hooks.make"
  include
    struct
      type props =
        | Props of React.element [@@unboxed ]
      let __melhole_hook_3 = Melact_runtime.Hook.key ()
      let makeProps ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melact_runtime.Instance.component __melhole_component_2 [||]
               (fun () ->
                  React.to_child
                    (let (shown, _) = useToggle () in
                     (React.useEffect1 __melhole_hook_3) ((fun () -> None)
                       [@alert "+hook"]) [|shown|];
                     React.string (React.useContext Theme.context)))) in
        Props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : props -> React.element = "%identity"
    end

Reason input:

  $ cat > greeting.re <<'EOF'
  > [@react.component]
  > let make = (~name) => <span className="greeting"> {React.string("Hello, " ++ name)} </span>;
  > EOF
  $ refmt --print ml greeting.re > greeting.ml
  $ ./pp.exe -impl greeting.ml
  [@@@alert "-hook"]
  let __melhole_component_1 =
    Melact_runtime.Component.make ~name:"Greeting.make"
  include
    struct
      type props =
        | Props of React.element [@@unboxed ]
      let __melhole_template_2 =
        Melhole.View.template
          (Melhole.Template.html "<span class=\"greeting\"></span>")
          {
            Js.Fn.I2 =
              (fun __melhole_scope __melhole_node ->
                 Melhole.Template.element __melhole_node)
          }
      let makeProps ~name:(name as __melhole_prop_0) ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_1
               [|(Melhole.View.Input __melhole_prop_0)|]
               (fun () ->
                  React.to_child
                    (React.of_child
                       (Melhole.View.compiled __melhole_template_2 2
                          {
                            Js.Fn.I2 =
                              (fun __melhole_scope __melhole_hole_0 ->
                                 let __melhole_changed_0 =
                                   Melhole.View.check __melhole_scope 0 name in
                                 (match __melhole_changed_0 with
                                  | Melhole.View.Unchanged -> ()
                                  | _ ->
                                      Melhole.View.put_sole_text
                                        __melhole_scope 1 __melhole_hole_0
                                        ("Hello, " ^ name : string));
                                 ())
                          })))) in
        Props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : props -> React.element = "%identity"
    end

mlx input:

  $ cat > greeting.mlx <<'EOF'
  > let[@react.component] make ~name =
  >   <span className="greeting">(React.string ("Hello, " ^ name))</span>
  > EOF
  $ mlx-pp greeting.mlx > greeting.ast
  $ ./pp.exe -impl greeting.ast
  [@@@alert "-hook"]
  let __melhole_component_1 =
    Melact_runtime.Component.make ~name:"Greeting.make"
  include
    struct
      type props =
        | Props of React.element [@@unboxed ]
      let __melhole_template_2 =
        Melhole.View.template
          (Melhole.Template.html "<span class=\"greeting\"></span>")
          {
            Js.Fn.I2 =
              (fun __melhole_scope __melhole_node ->
                 Melhole.Template.element __melhole_node)
          }
      let makeProps ~name:(name as __melhole_prop_0) ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_1
               [|(Melhole.View.Input __melhole_prop_0)|]
               (fun () ->
                  React.to_child
                    (React.of_child
                       (Melhole.View.compiled __melhole_template_2 2
                          {
                            Js.Fn.I2 =
                              (fun __melhole_scope __melhole_hole_0 ->
                                 let __melhole_changed_0 =
                                   Melhole.View.check __melhole_scope 0 name in
                                 (match __melhole_changed_0 with
                                  | Melhole.View.Unchanged -> ()
                                  | _ ->
                                      Melhole.View.put_sole_text
                                        __melhole_scope 1 __melhole_hole_0
                                        ("Hello, " ^ name : string));
                                 ())
                          })))) in
        Props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : props -> React.element = "%identity"
    end

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

Hooks keep their order: the hook alert is off in the file and back on in branches, loops and
callbacks of a component, so a hook called there is reported by the type checker, through any alias:

  $ cat > rules.ml <<'EOF'
  > let make ~flag =
  >   let count, setCount = React.useState (fun () -> 0) in
  >   let extra = if flag then 1 else 0 in
  >   ((button ~onClick:(fun _ -> setCount (fun n -> n + extra)) ~children:[ React.int count ] ()) [@JSX])
  > [@@react.component]
  > EOF
  $ ./pp.exe -impl rules.ml | grep -n "alert"
  1:[@@@alert "-hook"]
  27:                       [@alert "+hook"]) in
  30:                     then ((1)[@alert "+hook"])
  31:                     else ((0)[@alert "+hook"]) in
  58:                                               [@alert "+hook"]))
  59:                                           [@alert "+hook"])

Bindings to npm's react: dependencies typed as an n-tuple pick the hook with n dependencies, an
array the one with an array; uses below become Melact's hooks with their own keys, and the binding
stays as a definition other files can call, with no limit on the number of dependencies:

  $ cat > npm.ml <<'EOF'
  > external useEffect3 : (unit -> (unit -> unit) option) -> 'a * 'b * 'c -> unit = "useEffect" [@@mel.module "react"]
  > external useEffect8 : (unit -> (unit -> unit) option) -> int array -> unit = "useEffect" [@@mel.module "react"]
  > let use a = useEffect3 (fun () -> None) (a, "x", 1.0); useEffect8 (fun () -> None) [| a; 1; 2; 3; 4; 5; 6; 7 |]
  > EOF
  $ ./pp.exe -impl npm.ml
  [@@@alert "-hook"]
  let melact_key_useEffect3 = Melact_runtime.Hook.key ()[@@warning "-32"]
  let useEffect3 melact_argument_0 melact_argument_1 =
    React.useEffect3 (Melact_runtime.Hook.unchecked melact_key_useEffect3)
      melact_argument_0 melact_argument_1[@@warning "-32"]
  let melact_key_useEffect8 = Melact_runtime.Hook.key ()[@@warning "-32"]
  let useEffect8 melact_argument_0 melact_argument_1 =
    React.useEffect1 (Melact_runtime.Hook.unchecked melact_key_useEffect8)
      melact_argument_0 melact_argument_1[@@warning "-32"]
  let __melhole_hook_1 = Melact_runtime.Hook.key ()
  let __melhole_hook_2 = Melact_runtime.Hook.key ()
  let use a =
    (React.useEffect3 __melhole_hook_1) (fun () -> None) (a, "x", 1.0);
    (React.useEffect1 __melhole_hook_2) (fun () -> None) [|a;1;2;3;4;5;6;7|]

A tuple longer than the numbered hooks take is passed as the array it is in JavaScript, and uses
call the binding's definition:

  $ cat > long.ml <<'EOF'
  > external useMemo8 : (unit -> 'v) -> 'a * 'b * 'c * 'd * 'e * 'f * 'g * 'h -> 'v = "useMemo" [@@mel.module "react"]
  > let use a = useMemo8 (fun () -> a) (a, 1, 2, 3, 4, 5, 6, "x")
  > EOF
  $ ./pp.exe -impl long.ml
  [@@@alert "-hook"]
  let melact_key_useMemo8 = Melact_runtime.Hook.key ()[@@warning "-32"]
  let useMemo8 melact_argument_0 melact_argument_1 =
    React.useMemo1 (Melact_runtime.Hook.unchecked melact_key_useMemo8)
      melact_argument_0 (Melact_runtime.Hook.listed melact_argument_1)[@@warning
                                                                      "-32"]
  let use a = useMemo8 (fun () -> a) (a, 1, 2, 3, 4, 5, 6, "x")
