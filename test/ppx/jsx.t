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
      (Melact_view.View.tpl_instance __melact_template_1
         [|(Melact_view.View.HText (name : string));(Melact_view.View.HChild
                                                       ((let React.Element
                                                           __melact_child =
                                                           extra in
                                                         __melact_child)));(
           Melact_view.View.HChild
             ((let React.Element __melact_child = extra in __melact_child)));(
           Melact_view.View.HText (string_of_int (count : int)))|])

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
        (Melact_view.View.tpl_instance __melact_template_1
           [|(Melact_view.View.HAttr (Some (text : string)));(Melact_view.View.HAttr
                                                                (if
                                                                   (flag : 
                                                                   bool)
                                                                 then Some ""
                                                                 else None));(
             Melact_view.View.HAttr
               (Some (if (flag : bool) then "true" else "false")));(Melact_view.View.HAttr
                                                                      (
                                                                      Some
                                                                      (string_of_int
                                                                      (tab : 
                                                                      int))));(
             Melact_view.View.HProp (text : string));(Melact_view.View.HProp
                                                        (flag : bool));(
             Melact_view.View.HStyle (ReactDOM.Style.declarations style));(
             Melact_view.View.HRef
               ((let ReactDOM.Dom_ref apply = ref in apply)));(Melact_view.View.HAttr
                                                                 (maybe : 
                                                                 string option));(
             Melact_view.View.HHandler
               ((fun __melact_event ->
                   onInput (ReactEvent.Form.Native __melact_event))));(
             Melact_view.View.HHandler
               ((fun __melact_event ->
                   Option.iter
                     (fun handle ->
                        handle (ReactEvent.Keyboard.Native __melact_event))
                     None)))|])),
      (React.Element
         (Melact_view.View.tpl_instance __melact_template_2
            [|(Melact_view.View.HProp (html ## __html))|])))

A component with optional, defaulted and children props, and its signature:

  $ cat > card.ml <<'EOF'
  > let make ~title ?(size = 1) ?subtitle ~children () =
  >   ((section ~children:[ React.string title; children ] ()) [@JSX])
  > [@@react.component]
  > let nothing = fun () -> React.null [@@react.component]
  > EOF
  $ ./pp.exe -impl card.ml
  let __melact_component_1 =
    Melact_view.Component.make ~name:"Card.make"
      ~unchanged:(fun
                    (__melact_prop_0_old, __melact_prop_1_old,
                     __melact_prop_2_old, __melact_prop_3_old)
                    (__melact_prop_0_new, __melact_prop_1_new,
                     __melact_prop_2_new, __melact_prop_3_new)
                    ->
                    (__melact_prop_0_old == __melact_prop_0_new) &&
                      ((__melact_prop_1_old == __melact_prop_1_new) &&
                         ((__melact_prop_2_old == __melact_prop_2_new) &&
                            (__melact_prop_3_old == __melact_prop_3_new))))
  let __melact_template_2 =
    Melact_view.Template.make ~html:"<section><!----></section>"
      ~holes:[|(Melact_view.Template.Text ([], 0));(Melact_view.Template.Child
                                                      ([], 1))|]
  let make =
    ((fun ~title:(title as __melact_prop_0) ?size:((size as __melact_prop_1)=
        1) ?subtitle:(subtitle as __melact_prop_2)
        ~children:(children as __melact_prop_3) () ->
        React.Element
          (Melact_view.View.component __melact_component_1
             (__melact_prop_0, __melact_prop_1, __melact_prop_2,
               __melact_prop_3)
             (fun (title, size, subtitle, children) ->
                let React.Element __melact_child =
                  React.Element
                    (Melact_view.View.tpl_instance __melact_template_2
                       [|(Melact_view.View.HText (title : string));(Melact_view.View.HChild
                                                                      ((
                                                                      let React.Element
                                                                      __melact_child
                                                                      =
                                                                      children in
                                                                      __melact_child)))|]) in
                __melact_child)))
    [@ocaml.warning "-26-27"])
  let __melact_component_3 =
    Melact_view.Component.make ~name:"Card.nothing"
      ~unchanged:(fun () () -> true)
  let nothing =
    ((fun () ->
        React.Element
          (Melact_view.View.component __melact_component_3 ()
             (fun () ->
                let React.Element __melact_child = React.null in __melact_child)))
    [@ocaml.warning "-26-27"])
  $ cat > card.mli <<'EOF'
  > val make : title:string -> ?size:int -> ?subtitle:string -> children:React.element -> React.element
  > [@@react.component]
  > EOF
  $ ./pp.exe -intf card.mli
  val make :
    title:string ->
      ?size:int ->
        ?subtitle:string -> children:React.element -> unit -> React.element

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
                      (Melact_view.View.tpl_instance __melact_template_1
                         [|(Melact_view.View.HText (item : string))|]) in
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
  let __melact_component_2 =
    Melact_view.Component.make ~name:"Hooks.make"
      ~unchanged:(fun () () -> true)
  let __melact_hook_3 = Melact_view.Hook.key ()
  let make =
    ((fun () ->
        React.Element
          (Melact_view.View.component __melact_component_2 ()
             (fun () ->
                let React.Element __melact_child =
                  let (shown, _) = useToggle () in
                  (React.useEffect1 __melact_hook_3) (fun () -> None) [|shown|];
                  React.string (React.useContext Theme.context) in
                __melact_child)))
    [@ocaml.warning "-26-27"])

Reason input:

  $ cat > greeting.re <<'EOF'
  > [@react.component]
  > let make = (~name) => <span className="greeting"> {React.string("Hello, " ++ name)} </span>;
  > EOF
  $ refmt --print ml greeting.re > greeting.ml
  $ ./pp.exe -impl greeting.ml
  let __melact_component_1 =
    Melact_view.Component.make ~name:"Greeting.make" ~unchanged:(==)
  let __melact_template_2 =
    Melact_view.Template.make ~html:"<span class=\"greeting\"></span>"
      ~holes:[|(Melact_view.Template.Text ([], 0))|]
  let make =
    ((fun ~name:(name as __melact_prop_0) () ->
        React.Element
          (Melact_view.View.component __melact_component_1 __melact_prop_0
             (fun name ->
                let React.Element __melact_child =
                  React.Element
                    (Melact_view.View.tpl_instance __melact_template_2
                       [|(Melact_view.View.HText ("Hello, " ^ name : string))|]) in
                __melact_child)))
    [@ocaml.warning "-26-27"])

mlx input:

  $ cat > greeting.mlx <<'EOF'
  > let[@react.component] make ~name =
  >   <span className="greeting">(React.string ("Hello, " ^ name))</span>
  > EOF
  $ mlx-pp greeting.mlx > greeting.ast
  $ ./pp.exe -impl greeting.ast
  let __melact_component_1 =
    Melact_view.Component.make ~name:"Greeting.make" ~unchanged:(==)
  let __melact_template_2 =
    Melact_view.Template.make ~html:"<span class=\"greeting\"></span>"
      ~holes:[|(Melact_view.Template.Text ([], 0))|]
  let make =
    ((fun ~name:(name as __melact_prop_0) () ->
        React.Element
          (Melact_view.View.component __melact_component_1 __melact_prop_0
             (fun name ->
                let React.Element __melact_child =
                  React.Element
                    (Melact_view.View.tpl_instance __melact_template_2
                       [|(Melact_view.View.HText ("Hello, " ^ name : string))|]) in
                __melact_child)))
    [@ocaml.warning "-26-27"])

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
