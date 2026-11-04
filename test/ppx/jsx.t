A static tree becomes one template and one hoisted element:

  $ cat > static.ml <<'EOF'
  > let header = ((header ~className:"top" ~children:[ ((h1 ~children:[ React.string "Hi & <bye>" ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl static.ml
  let __melhole_template_1 =
    Melhole.Template.make
      ~html:"<header class=\"top\"><h1>Hi &amp; &lt;bye&gt;</h1></header>"
      ~holes:[||]
  let __melhole_element_2 =
    React.Element (Melhole.View.tpl_instance __melhole_template_1 [||])
  let header = __melhole_element_2

Holes at every depth; markers only between neighbours that would merge:

  $ cat > holes.ml <<'EOF'
  > let row ~name ~count ~extra =
  >   ((p ~children:[ React.string "a"; React.string name; React.string "b"; extra; extra;
  >                   ((b ~children:[ React.int count ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl holes.ml
  let __melhole_template_1 =
    Melhole.Template.make ~html:"<p>a<!---->b<!----><b></b></p>"
      ~holes:[|(Melhole.Template.Text ([], 1));(Melhole.Template.Child ([], 3));(
               Melhole.Template.Child ([], 4));(Melhole.Template.Text ([4], 0))|]
  let row ~name ~count ~extra =
    React.Element
      (Melhole.View.guarded __melhole_template_1 3
         (fun __melhole_block ->
            let __melhole_changed_0 =
              Melhole.View.check __melhole_block 0 count in
            let __melhole_changed_1 =
              Melhole.View.check __melhole_block 1 extra in
            let __melhole_changed_2 = Melhole.View.check __melhole_block 2 name in
            (match __melhole_changed_2 with
             | Melhole.View.Unchanged -> ()
             | _ -> Melhole.View.put_text __melhole_block 0 (name : string));
            (match __melhole_changed_1 with
             | Melhole.View.Unchanged -> ()
             | _ ->
                 Melhole.View.put_child __melhole_block 1
                   (let React.Element __melhole_child = extra in
                    __melhole_child));
            (match __melhole_changed_1 with
             | Melhole.View.Unchanged -> ()
             | _ ->
                 Melhole.View.put_child __melhole_block 2
                   (let React.Element __melhole_child = extra in
                    __melhole_child));
            (match __melhole_changed_0 with
             | Melhole.View.Unchanged -> ()
             | _ ->
                 Melhole.View.put_text __melhole_block 3
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
    Melhole.Template.make ~html:"<input id=\"name\" required maxLength=\"3\">"
      ~holes:[|(Melhole.Template.Attr ([], "class"));(Melhole.Template.Attr
                                                        ([], "disabled"));(
               Melhole.Template.Attr ([], "aria-hidden"));(Melhole.Template.Attr
                                                             ([], "tabIndex"));(
               Melhole.Template.Prop ([], "value"));(Melhole.Template.Prop
                                                       ([], "checked"));(
               Melhole.Template.Style []);(Melhole.Template.Ref []);(Melhole.Template.Attr
                                                                      ([],
                                                                      "title"));(
               Melhole.Template.Handler ([], "input"));(Melhole.Template.Handler
                                                          ([], "keydown"))|]
  let __melhole_template_2 =
    Melhole.Template.make ~html:"<div stroke-width=\"2\" for=\"x\"></div>"
      ~holes:[|(Melhole.Template.Prop ([], "innerHTML"))|]
  let form ~text ~flag ~tab ~opacity ~style ~ref ~maybe ~html ~onInput =
    ((React.Element
        (Melhole.View.guarded __melhole_template_1 5
           (fun __melhole_block ->
              let __melhole_changed_0 =
                Melhole.View.check __melhole_block 0 flag in
              let __melhole_changed_1 =
                Melhole.View.check __melhole_block 1 maybe in
              let __melhole_changed_2 =
                Melhole.View.check __melhole_block 2 style in
              let __melhole_changed_3 =
                Melhole.View.check __melhole_block 3 tab in
              let __melhole_changed_4 =
                Melhole.View.check __melhole_block 4 text in
              (match __melhole_changed_4 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.put_attr __melhole_block 0
                     (Some (text : string)));
              (match __melhole_changed_0 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.put_attr __melhole_block 1
                     (if (flag : bool) then Some "" else None));
              (match __melhole_changed_0 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.put_attr __melhole_block 2
                     (Some (if (flag : bool) then "true" else "false")));
              (match __melhole_changed_3 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.put_attr __melhole_block 3
                     (Some (string_of_int (tab : int))));
              (match __melhole_changed_4 with
               | Melhole.View.Unchanged -> ()
               | _ -> Melhole.View.put_prop __melhole_block 4 (text : string));
              (match __melhole_changed_0 with
               | Melhole.View.Unchanged -> ()
               | _ -> Melhole.View.put_prop __melhole_block 5 (flag : bool));
              (match __melhole_changed_2 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.put_style __melhole_block 6
                     (ReactDOM.Style.declarations style));
              Melhole.View.put_ref __melhole_block 7 (ReactDOM.Ref.attach ref);
              (match __melhole_changed_1 with
               | Melhole.View.Unchanged -> ()
               | _ ->
                   Melhole.View.put_attr __melhole_block 8
                     (maybe : string option));
              Melhole.View.put_handler __melhole_block 9
                (fun __melhole_event ->
                   onInput (ReactEvent.Form.Native __melhole_event));
              Melhole.View.put_handler __melhole_block 10
                (fun __melhole_event ->
                   Option.iter
                     (fun handle ->
                        handle (ReactEvent.Keyboard.Native __melhole_event))
                     None);
              ()))),
      (React.Element
         (Melhole.View.guarded __melhole_template_2 1
            (fun __melhole_block ->
               let __melhole_changed_0 =
                 Melhole.View.check __melhole_block 0 html in
               (match __melhole_changed_0 with
                | Melhole.View.Unchanged -> ()
                | _ -> Melhole.View.put_prop __melhole_block 0 (html ## __html));
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
    Melhole.Template.make ~html:"<section><!----></section>"
      ~holes:[|(Melhole.Template.Text ([], 0));(Melhole.Template.Child ([], 1))|]
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
                (Melhole.View.guarded __melhole_template_2 2
                   (fun __melhole_block ->
                      let __melhole_changed_0 =
                        Melhole.View.check __melhole_block 0 children in
                      let __melhole_changed_1 =
                        Melhole.View.check __melhole_block 1 title in
                      (match __melhole_changed_1 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.put_text __melhole_block 0
                             (title : string));
                      (match __melhole_changed_0 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.put_child __melhole_block 1
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
    Melhole.Template.make ~html:"<input>"
      ~holes:[|(Melhole.Template.Attr ([], "placeholder"));(Melhole.Template.Ref
                                                              [])|]
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
                (Melhole.View.guarded __melhole_template_2 1
                   (fun __melhole_block ->
                      let __melhole_changed_0 =
                        Melhole.View.check __melhole_block 0 label in
                      (match __melhole_changed_0 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.put_attr __melhole_block 0
                             (Some (label : string)));
                      Melhole.View.put_ref __melhole_block 1
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
    Melhole.Template.make ~html:"<li></li>"
      ~holes:[|(Melhole.Template.Text ([], 0))|]
  let rows items =
    React.array
      (Array.map
         (fun item ->
            React.Element
              (Melhole.View.with_key (item : string)
                 (let React.Element __melhole_child =
                    React.Element
                      (Melhole.View.guarded __melhole_template_1 1
                         (fun __melhole_block ->
                            let __melhole_changed_0 =
                              Melhole.View.check __melhole_block 0 item in
                            (match __melhole_changed_0 with
                             | Melhole.View.Unchanged -> ()
                             | _ ->
                                 Melhole.View.put_text __melhole_block 0
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
    Melhole.Template.make ~html:"<span class=\"greeting\"></span>"
      ~holes:[|(Melhole.Template.Text ([], 0))|]
  let make ~name:(name as __melhole_prop_0) () =
    React.Element
      (Melhole.View.component __melhole_component_1
         [|(Melhole.View.Input __melhole_prop_0)|]
         (fun () ->
            let React.Element __melhole_child =
              React.Element
                (Melhole.View.guarded __melhole_template_2 1
                   (fun __melhole_block ->
                      let __melhole_changed_0 =
                        Melhole.View.check __melhole_block 0 name in
                      (match __melhole_changed_0 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.put_text __melhole_block 0
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
    Melhole.Template.make ~html:"<span class=\"greeting\"></span>"
      ~holes:[|(Melhole.Template.Text ([], 0))|]
  let make ~name:(name as __melhole_prop_0) () =
    React.Element
      (Melhole.View.component __melhole_component_1
         [|(Melhole.View.Input __melhole_prop_0)|]
         (fun () ->
            let React.Element __melhole_child =
              React.Element
                (Melhole.View.guarded __melhole_template_2 1
                   (fun __melhole_block ->
                      let __melhole_changed_0 =
                        Melhole.View.check __melhole_block 0 name in
                      (match __melhole_changed_0 with
                       | Melhole.View.Unchanged -> ()
                       | _ ->
                           Melhole.View.put_text __melhole_block 0
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
