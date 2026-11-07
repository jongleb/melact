A static tree becomes one template and one hoisted element:

  $ cat > static.ml <<'EOF'
  > let header = ((header ~className:"top" ~children:[ ((h1 ~children:[ React.string "Hi & <bye>" ] ()) [@JSX]) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl static.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
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
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  type ('melhole_0, 'melhole_1, 'melhole_2, 'melhole_3) __melhole_frame_1 =
    {
    __melhole_frame_1_hole_0: 'melhole_0 ;
    __melhole_frame_1_hole_1: 'melhole_1 ;
    __melhole_frame_1_hole_2: 'melhole_2 ;
    __melhole_frame_1_hole_3: 'melhole_3 ;
    mutable __melhole_frame_1_slot_0: Melhole.View.input ;
    mutable __melhole_frame_1_slot_1: Melhole.View.input ;
    mutable __melhole_frame_1_slot_2: Melhole.View.input }[@@ocaml.warning
                                                            "-34-69"]
  let __melhole_template_2 =
    Melhole.View.template
      (Melhole.Template.html "<p>a<!---->b<!----><b></b></p>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             let __melhole_node_0 = Melhole.Template.first __melhole_node in
             let __melhole_node_1 = Melhole.Template.next __melhole_node_0 in
             let __melhole_node_2 = Melhole.Template.next __melhole_node_1 in
             let __melhole_node_3 = Melhole.Template.next __melhole_node_2 in
             let __melhole_node_4 = Melhole.Template.next __melhole_node_3 in
             {
               __melhole_frame_1_hole_0 =
                 (Melhole.View.text_at
                    {
                      Melhole.Template.parent = __melhole_node;
                      before = (Melhole.Template.next_or_end __melhole_node_0)
                    });
               __melhole_frame_1_hole_1 =
                 (Melhole.View.content_hole
                    {
                      Melhole.Template.parent = __melhole_node;
                      before = (Melhole.Template.next_or_end __melhole_node_2)
                    });
               __melhole_frame_1_hole_2 =
                 (Melhole.View.content_hole
                    {
                      Melhole.Template.parent = __melhole_node;
                      before = (Melhole.Template.next_or_end __melhole_node_3)
                    });
               __melhole_frame_1_hole_3 =
                 (Melhole.Template.element __melhole_node_4);
               __melhole_frame_1_slot_0 = Melhole.View.unset;
               __melhole_frame_1_slot_1 = Melhole.View.unset;
               __melhole_frame_1_slot_2 = Melhole.View.unset
             })
      }
      {
        Melhole.View.placed = None;
        released =
          (Some
             {
               Js.Fn.I1 =
                 (fun __melhole_frame ->
                    Melhole.View.release_content
                      __melhole_frame.__melhole_frame_1_hole_1;
                    Melhole.View.release_content
                      __melhole_frame.__melhole_frame_1_hole_2)
             });
        forgotten =
          (Some
             {
               Js.Fn.I1 =
                 (fun __melhole_frame ->
                    (__melhole_frame.__melhole_frame_1_slot_0 <-
                       (Melhole.View.Input Melhole.View.unset);
                     __melhole_frame.__melhole_frame_1_slot_1 <-
                       (Melhole.View.Input Melhole.View.unset));
                    __melhole_frame.__melhole_frame_1_slot_2 <-
                      (Melhole.View.Input Melhole.View.unset))
             })
      }
  let row ~name ~count ~extra =
    React.of_child
      (Melhole.View.compiled __melhole_template_2
         {
           Js.Fn.I1 =
             (fun __melhole_frame ->
                ((let __melhole_hole_0 =
                    __melhole_frame.__melhole_frame_1_hole_0 in
                  let __melhole_hole_1 =
                    __melhole_frame.__melhole_frame_1_hole_1 in
                  let __melhole_hole_2 =
                    __melhole_frame.__melhole_frame_1_hole_2 in
                  let __melhole_hole_3 =
                    __melhole_frame.__melhole_frame_1_hole_3 in
                  let __melhole_changed_0 =
                    Melhole.View.check __melhole_frame.__melhole_frame_1_slot_0
                      count in
                  __melhole_frame.__melhole_frame_1_slot_0 <-
                    (Melhole.View.Input count);
                  (let __melhole_changed_1 =
                     Melhole.View.check
                       __melhole_frame.__melhole_frame_1_slot_1 extra in
                   __melhole_frame.__melhole_frame_1_slot_1 <-
                     (Melhole.View.Input extra);
                   (let __melhole_changed_2 =
                      Melhole.View.check
                        __melhole_frame.__melhole_frame_1_slot_2 name in
                    __melhole_frame.__melhole_frame_1_slot_2 <-
                      (Melhole.View.Input name);
                    (match __melhole_changed_2 with
                     | Melhole.View.Unchanged -> ()
                     | _ ->
                         Melhole.Dom_api.set_data __melhole_hole_0
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
                         Melhole.View.write_sole_text __melhole_hole_3
                           (string_of_int (count : int)));
                    ())))
                [@ocaml.warning "-26-27"]))
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
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let __melhole_delegated_1 = Melhole.Events.delegate "onchange"
  let __melhole_event_2 = Melhole.View.event_key "onchange"
  let __melhole_delegated_3 = Melhole.Events.delegate "keydown"
  let __melhole_event_4 = Melhole.View.event_key "keydown"
  type ('melhole_0, 'melhole_1, 'melhole_2, 'melhole_3,
    'melhole_4) __melhole_frame_5 =
    {
    __melhole_frame_5_hole_0: 'melhole_0 ;
    __melhole_frame_5_hole_4: 'melhole_1 ;
    __melhole_frame_5_hole_5: 'melhole_2 ;
    __melhole_frame_5_hole_6: 'melhole_3 ;
    __melhole_frame_5_hole_7: 'melhole_4 ;
    mutable __melhole_frame_5_slot_0: Melhole.View.input ;
    mutable __melhole_frame_5_slot_1: Melhole.View.input ;
    mutable __melhole_frame_5_slot_2: Melhole.View.input ;
    mutable __melhole_frame_5_slot_3: Melhole.View.input ;
    mutable __melhole_frame_5_slot_4: Melhole.View.input ;
    mutable __melhole_frame_5_slot_5: Melhole.View.input ;
    mutable __melhole_frame_5_slot_6: Melhole.View.input ;
    mutable __melhole_frame_5_slot_7: Melhole.View.input ;
    mutable __melhole_frame_5_slot_8: Melhole.View.input }[@@ocaml.warning
                                                            "-34-69"]
  let __melhole_template_6 =
    Melhole.View.template
      (Melhole.Template.html "<input id=\"name\" required maxLength=\"3\">")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             {
               __melhole_frame_5_hole_0 =
                 (Melhole.Template.element __melhole_node);
               __melhole_frame_5_hole_4 =
                 (Melhole.View.controlled_hole
                    (Melhole.Template.element __melhole_node) "value");
               __melhole_frame_5_hole_5 =
                 (Melhole.View.controlled_hole
                    (Melhole.Template.element __melhole_node) "checked");
               __melhole_frame_5_hole_6 =
                 (Melhole.View.style_hole
                    (Melhole.Template.element __melhole_node));
               __melhole_frame_5_hole_7 =
                 (Melhole.View.reference_hole
                    (Melhole.Template.element __melhole_node));
               __melhole_frame_5_slot_0 = Melhole.View.unset;
               __melhole_frame_5_slot_1 = Melhole.View.unset;
               __melhole_frame_5_slot_2 = Melhole.View.unset;
               __melhole_frame_5_slot_3 = Melhole.View.unset;
               __melhole_frame_5_slot_4 = Melhole.View.unset;
               __melhole_frame_5_slot_5 = Melhole.View.unset;
               __melhole_frame_5_slot_6 = Melhole.View.unset;
               __melhole_frame_5_slot_7 = Melhole.View.unset;
               __melhole_frame_5_slot_8 = Melhole.View.unset
             })
      }
      {
        Melhole.View.placed =
          (Some
             {
               Js.Fn.I1 =
                 (fun __melhole_frame ->
                    Melhole.View.place_reference
                      __melhole_frame.__melhole_frame_5_hole_7)
             });
        released =
          (Some
             {
               Js.Fn.I1 =
                 (fun __melhole_frame ->
                    Melhole.View.release_reference
                      __melhole_frame.__melhole_frame_5_hole_7)
             });
        forgotten =
          (Some
             {
               Js.Fn.I1 =
                 (fun __melhole_frame ->
                    (((((((__melhole_frame.__melhole_frame_5_slot_0 <-
                             (Melhole.View.Input Melhole.View.unset);
                           __melhole_frame.__melhole_frame_5_slot_1 <-
                             (Melhole.View.Input Melhole.View.unset));
                          __melhole_frame.__melhole_frame_5_slot_2 <-
                            (Melhole.View.Input Melhole.View.unset));
                         __melhole_frame.__melhole_frame_5_slot_3 <-
                           (Melhole.View.Input Melhole.View.unset));
                        __melhole_frame.__melhole_frame_5_slot_4 <-
                          (Melhole.View.Input Melhole.View.unset));
                       __melhole_frame.__melhole_frame_5_slot_5 <-
                         (Melhole.View.Input Melhole.View.unset));
                      __melhole_frame.__melhole_frame_5_slot_6 <-
                        (Melhole.View.Input Melhole.View.unset));
                     __melhole_frame.__melhole_frame_5_slot_7 <-
                       (Melhole.View.Input Melhole.View.unset));
                    __melhole_frame.__melhole_frame_5_slot_8 <-
                      (Melhole.View.Input Melhole.View.unset))
             })
      }
  type 'melhole_0 __melhole_frame_7 =
    {
    __melhole_frame_7_hole_0: 'melhole_0 ;
    mutable __melhole_frame_7_slot_0: Melhole.View.input }[@@ocaml.warning
                                                            "-34-69"]
  let __melhole_template_8 =
    Melhole.View.template
      (Melhole.Template.html "<div stroke-width=\"2\" for=\"x\"></div>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             {
               __melhole_frame_7_hole_0 =
                 (Melhole.View.prop_hole
                    (Melhole.Template.element __melhole_node) "innerHTML");
               __melhole_frame_7_slot_0 = Melhole.View.unset
             })
      }
      {
        Melhole.View.placed = None;
        released = None;
        forgotten =
          (Some
             {
               Js.Fn.I1 =
                 (fun __melhole_frame ->
                    __melhole_frame.__melhole_frame_7_slot_0 <-
                      (Melhole.View.Input Melhole.View.unset))
             })
      }
  let form ~text ~flag ~tab ~opacity ~style ~ref ~maybe ~html ~onInput =
    ((React.of_child
        (Melhole.View.compiled __melhole_template_6
           {
             Js.Fn.I1 =
               (fun __melhole_frame ->
                  ((let __melhole_hole_0 =
                      __melhole_frame.__melhole_frame_5_hole_0 in
                    let __melhole_hole_4 =
                      __melhole_frame.__melhole_frame_5_hole_4 in
                    let __melhole_hole_5 =
                      __melhole_frame.__melhole_frame_5_hole_5 in
                    let __melhole_hole_6 =
                      __melhole_frame.__melhole_frame_5_hole_6 in
                    let __melhole_hole_7 =
                      __melhole_frame.__melhole_frame_5_hole_7 in
                    let __melhole_hole_1 = __melhole_hole_0 in
                    let __melhole_hole_2 = __melhole_hole_0 in
                    let __melhole_hole_3 = __melhole_hole_0 in
                    let __melhole_hole_8 = __melhole_hole_0 in
                    let __melhole_hole_9 = __melhole_hole_0 in
                    let __melhole_hole_10 = __melhole_hole_0 in
                    let __melhole_key_9 = __melhole_event_2 in
                    let __melhole_key_10 = __melhole_event_4 in
                    let __melhole_changed_0 =
                      Melhole.View.check
                        __melhole_frame.__melhole_frame_5_slot_0 flag in
                    __melhole_frame.__melhole_frame_5_slot_0 <-
                      (Melhole.View.Input flag);
                    (let __melhole_changed_1 =
                       Melhole.View.check
                         __melhole_frame.__melhole_frame_5_slot_1 maybe in
                     __melhole_frame.__melhole_frame_5_slot_1 <-
                       (Melhole.View.Input maybe);
                     (let __melhole_changed_2 =
                        Melhole.View.check
                          __melhole_frame.__melhole_frame_5_slot_2 onInput in
                      __melhole_frame.__melhole_frame_5_slot_2 <-
                        (Melhole.View.Input onInput);
                      (let __melhole_changed_3 =
                         Melhole.View.check
                           __melhole_frame.__melhole_frame_5_slot_3 style in
                       __melhole_frame.__melhole_frame_5_slot_3 <-
                         (Melhole.View.Input style);
                       (let __melhole_changed_4 =
                          Melhole.View.check
                            __melhole_frame.__melhole_frame_5_slot_4 tab in
                        __melhole_frame.__melhole_frame_5_slot_4 <-
                          (Melhole.View.Input tab);
                        (let __melhole_changed_5 =
                           Melhole.View.check
                             __melhole_frame.__melhole_frame_5_slot_5 text in
                         __melhole_frame.__melhole_frame_5_slot_5 <-
                           (Melhole.View.Input text);
                         (let __melhole_changed_6 =
                            Melhole.View.check
                              __melhole_frame.__melhole_frame_5_slot_6 () in
                          __melhole_frame.__melhole_frame_5_slot_6 <-
                            (Melhole.View.Input ());
                          (match __melhole_changed_5 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               Melhole.View.write_attr __melhole_hole_0 "class"
                                 (Some (text : string)));
                          (match __melhole_changed_0 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               let __melhole_value =
                                 if (flag : bool) then Some "" else None in
                               (Melhole.View.put_attr
                                  __melhole_frame.__melhole_frame_5_slot_7
                                  __melhole_hole_1 "disabled" __melhole_value;
                                __melhole_frame.__melhole_frame_5_slot_7 <-
                                  (Melhole.View.Input __melhole_value)));
                          (match __melhole_changed_0 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               let __melhole_value =
                                 Some
                                   (if (flag : bool) then "true" else "false") in
                               (Melhole.View.put_attr
                                  __melhole_frame.__melhole_frame_5_slot_8
                                  __melhole_hole_2 "aria-hidden"
                                  __melhole_value;
                                __melhole_frame.__melhole_frame_5_slot_8 <-
                                  (Melhole.View.Input __melhole_value)));
                          (match __melhole_changed_4 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               Melhole.View.write_attr __melhole_hole_3
                                 "tabIndex" (Some (string_of_int (tab : int))));
                          (match __melhole_changed_5 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               Melhole.View.set_prop __melhole_hole_4
                                 (text : string));
                          (match __melhole_changed_0 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               Melhole.View.set_prop __melhole_hole_5
                                 (flag : bool));
                          (match __melhole_changed_3 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               Melhole.View.set_style __melhole_hole_6
                                 (ReactDOM.Style.declarations style));
                          Melhole.View.set_reference __melhole_hole_7
                            (ReactDOM.Ref.identity ref)
                            (ReactDOM.Ref.attach ref);
                          (match __melhole_changed_1 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               Melhole.View.write_attr __melhole_hole_8 "title"
                                 (maybe : string option));
                          (match __melhole_changed_2 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               Melhole.View.put_handler __melhole_hole_9
                                 __melhole_key_9
                                 (fun __melhole_event ->
                                    onInput
                                      (React.Event.ofNative __melhole_event)));
                          (match __melhole_changed_6 with
                           | Melhole.View.Unchanged -> ()
                           | _ ->
                               Melhole.View.put_handler __melhole_hole_10
                                 __melhole_key_10
                                 (fun __melhole_event ->
                                    Stdlib.Option.iter
                                      (fun handle ->
                                         handle
                                           (React.Event.ofNative
                                              __melhole_event)) None));
                          ())))))))
                  [@ocaml.warning "-26-27"]))
           })),
      (React.of_child
         (Melhole.View.compiled __melhole_template_8
            {
              Js.Fn.I1 =
                (fun __melhole_frame ->
                   ((let __melhole_hole_0 =
                       __melhole_frame.__melhole_frame_7_hole_0 in
                     let __melhole_changed_0 =
                       Melhole.View.check
                         __melhole_frame.__melhole_frame_7_slot_0 html in
                     __melhole_frame.__melhole_frame_7_slot_0 <-
                       (Melhole.View.Input html);
                     (match __melhole_changed_0 with
                      | Melhole.View.Unchanged -> ()
                      | _ ->
                          Melhole.View.set_prop __melhole_hole_0
                            (Melhole.View.html_of html));
                     ())
                   [@ocaml.warning "-26-27"]))
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
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let __melhole_component_1 = Melact_runtime.Component.make ~name:"Card.make"
  include
    struct
      type make_props =
        | Make_props of React.element [@@unboxed ]
      type ('melhole_0, 'melhole_1) __melhole_frame_2 =
        {
        __melhole_frame_2_hole_0: 'melhole_0 ;
        __melhole_frame_2_hole_1: 'melhole_1 ;
        mutable __melhole_frame_2_slot_0: Melhole.View.input ;
        mutable __melhole_frame_2_slot_1: Melhole.View.input }[@@ocaml.warning
                                                                "-34-69"]
      let __melhole_template_3 =
        Melhole.View.template
          (Melhole.Template.html "<section><!----></section>")
          {
            Js.Fn.I1 =
              (fun __melhole_node ->
                 let __melhole_node_0 = Melhole.Template.first __melhole_node in
                 {
                   __melhole_frame_2_hole_0 =
                     (Melhole.View.text_at
                        {
                          Melhole.Template.parent = __melhole_node;
                          before =
                            (Melhole.Template.first_or_end __melhole_node)
                        });
                   __melhole_frame_2_hole_1 =
                     (Melhole.View.content_hole
                        {
                          Melhole.Template.parent = __melhole_node;
                          before =
                            (Melhole.Template.next_or_end __melhole_node_0)
                        });
                   __melhole_frame_2_slot_0 = Melhole.View.unset;
                   __melhole_frame_2_slot_1 = Melhole.View.unset
                 })
          }
          {
            Melhole.View.placed = None;
            released =
              (Some
                 {
                   Js.Fn.I1 =
                     (fun __melhole_frame ->
                        Melhole.View.release_content
                          __melhole_frame.__melhole_frame_2_hole_1)
                 });
            forgotten =
              (Some
                 {
                   Js.Fn.I1 =
                     (fun __melhole_frame ->
                        __melhole_frame.__melhole_frame_2_slot_0 <-
                          (Melhole.View.Input Melhole.View.unset);
                        __melhole_frame.__melhole_frame_2_slot_1 <-
                          (Melhole.View.Input Melhole.View.unset))
                 })
          }
      let makeProps ~title:(title as __melhole_prop_0)
        ?size:__melhole_prop_1_given ?subtitle:(subtitle as __melhole_prop_2)
        ~children:(children as __melhole_prop_3) ?key:__melhole_key () =
        let size as __melhole_prop_1 =
          match __melhole_prop_1_given with
          | Some __melhole_value when
              not (Js.Undefined.testAny __melhole_value) -> __melhole_value
          | Some _ | None -> 1 in
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_1
               [|(Melhole.View.Input __melhole_prop_0);(Melhole.View.Input
                                                          __melhole_prop_1);(
                 Melhole.View.Input __melhole_prop_3)|]
               (fun () ->
                  React.to_child
                    (React.of_child
                       (Melhole.View.compiled __melhole_template_3
                          {
                            Js.Fn.I1 =
                              (fun __melhole_frame ->
                                 ((let __melhole_hole_0 =
                                     __melhole_frame.__melhole_frame_2_hole_0 in
                                   let __melhole_hole_1 =
                                     __melhole_frame.__melhole_frame_2_hole_1 in
                                   let __melhole_changed_0 =
                                     Melhole.View.check
                                       __melhole_frame.__melhole_frame_2_slot_0
                                       children in
                                   __melhole_frame.__melhole_frame_2_slot_0 <-
                                     (Melhole.View.Input children);
                                   (let __melhole_changed_1 =
                                      Melhole.View.check
                                        __melhole_frame.__melhole_frame_2_slot_1
                                        title in
                                    __melhole_frame.__melhole_frame_2_slot_1 <-
                                      (Melhole.View.Input title);
                                    (match __melhole_changed_1 with
                                     | Melhole.View.Unchanged -> ()
                                     | _ ->
                                         Melhole.Dom_api.set_data
                                           __melhole_hole_0 (title : string));
                                    (match __melhole_changed_0 with
                                     | Melhole.View.Unchanged -> ()
                                     | _ ->
                                         Melhole.View.set_content
                                           __melhole_hole_1
                                           (React.to_child children));
                                    ()))
                                 [@ocaml.warning "-26-27"]))
                          })))) in
        Make_props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : make_props -> React.element = "%identity"
    end
  let __melhole_component_4 =
    Melact_runtime.Component.make ~name:"Card.nothing"
  include
    struct
      type nothing_props =
        | Nothing_props of React.element [@@unboxed ]
      let nothingProps ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_4 [||]
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
  type make_props
  val makeProps :
    title:string ->
      ?size:int ->
        ?subtitle:string ->
          children:React.element -> ?key:string -> unit -> make_props
  external make : make_props -> React.element = "%identity"

React.forwardRef: the ref becomes an optional prop and reaches the body as reason-react passes it:

  $ cat > fancy.ml <<'EOF'
  > let make = React.forwardRef (fun ~label ref ->
  >   ((input ~placeholder:label ?ref:(Option.map ReactDOM.Ref.domRef (Js.Nullable.toOption ref)) ()) [@JSX]))
  > [@@react.component]
  > EOF
  $ ./pp.exe -impl fancy.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let __melhole_component_1 = Melact_runtime.Component.make ~name:"Fancy.make"
  include
    struct
      type make_props =
        | Make_props of React.element [@@unboxed ]
      type ('melhole_0, 'melhole_1) __melhole_frame_2 =
        {
        __melhole_frame_2_hole_0: 'melhole_0 ;
        __melhole_frame_2_hole_1: 'melhole_1 ;
        mutable __melhole_frame_2_slot_0: Melhole.View.input }[@@ocaml.warning
                                                                "-34-69"]
      let __melhole_template_3 =
        Melhole.View.template (Melhole.Template.html "<input>")
          {
            Js.Fn.I1 =
              (fun __melhole_node ->
                 {
                   __melhole_frame_2_hole_0 =
                     (Melhole.Template.element __melhole_node);
                   __melhole_frame_2_hole_1 =
                     (Melhole.View.reference_hole
                        (Melhole.Template.element __melhole_node));
                   __melhole_frame_2_slot_0 = Melhole.View.unset
                 })
          }
          {
            Melhole.View.placed =
              (Some
                 {
                   Js.Fn.I1 =
                     (fun __melhole_frame ->
                        Melhole.View.place_reference
                          __melhole_frame.__melhole_frame_2_hole_1)
                 });
            released =
              (Some
                 {
                   Js.Fn.I1 =
                     (fun __melhole_frame ->
                        Melhole.View.release_reference
                          __melhole_frame.__melhole_frame_2_hole_1)
                 });
            forgotten =
              (Some
                 {
                   Js.Fn.I1 =
                     (fun __melhole_frame ->
                        __melhole_frame.__melhole_frame_2_slot_0 <-
                          (Melhole.View.Input Melhole.View.unset))
                 })
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
                       (Melhole.View.compiled __melhole_template_3
                          {
                            Js.Fn.I1 =
                              (fun __melhole_frame ->
                                 ((let __melhole_hole_0 =
                                     __melhole_frame.__melhole_frame_2_hole_0 in
                                   let __melhole_hole_1 =
                                     __melhole_frame.__melhole_frame_2_hole_1 in
                                   let __melhole_changed_0 =
                                     Melhole.View.check
                                       __melhole_frame.__melhole_frame_2_slot_0
                                       label in
                                   __melhole_frame.__melhole_frame_2_slot_0 <-
                                     (Melhole.View.Input label);
                                   (match __melhole_changed_0 with
                                    | Melhole.View.Unchanged -> ()
                                    | _ ->
                                        Melhole.View.write_attr
                                          __melhole_hole_0 "placeholder"
                                          (Some (label : string)));
                                   Melhole.View.set_reference __melhole_hole_1
                                     (Stdlib.Option.fold
                                        ~none:ReactDOM.Ref.absent
                                        ~some:ReactDOM.Ref.identity
                                        (Option.map ReactDOM.Ref.domRef
                                           (Js.Nullable.toOption ref)))
                                     (Stdlib.Option.fold ~none:ignore
                                        ~some:ReactDOM.Ref.attach
                                        (Option.map ReactDOM.Ref.domRef
                                           (Js.Nullable.toOption ref)));
                                   ())
                                 [@ocaml.warning "-26-27"]))
                          })))) in
        Make_props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : make_props -> React.element = "%identity"
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
  let () = React.reason_react_is_also_in_this_build_remove_it ()
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
  type 'melhole_0 __melhole_frame_1 =
    {
    __melhole_frame_1_hole_0: 'melhole_0 ;
    mutable __melhole_frame_1_slot_0: Melhole.View.input }[@@ocaml.warning
                                                            "-34-69"]
  let __melhole_template_2 =
    Melhole.View.template (Melhole.Template.html "<li></li>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             {
               __melhole_frame_1_hole_0 =
                 (Melhole.Template.element __melhole_node);
               __melhole_frame_1_slot_0 = Melhole.View.unset
             })
      }
      {
        Melhole.View.placed = None;
        released = None;
        forgotten =
          (Some
             {
               Js.Fn.I1 =
                 (fun __melhole_frame ->
                    __melhole_frame.__melhole_frame_1_slot_0 <-
                      (Melhole.View.Input Melhole.View.unset))
             })
      }
  let rows items =
    React.array
      (Array.map
         (fun item ->
            React.of_child
              (Melhole.View.with_key (item : string)
                 (React.to_child
                    (React.of_child
                       (Melhole.View.compiled __melhole_template_2
                          {
                            Js.Fn.I1 =
                              (fun __melhole_frame ->
                                 ((let __melhole_hole_0 =
                                     __melhole_frame.__melhole_frame_1_hole_0 in
                                   let __melhole_changed_0 =
                                     Melhole.View.check
                                       __melhole_frame.__melhole_frame_1_slot_0
                                       item in
                                   __melhole_frame.__melhole_frame_1_slot_0 <-
                                     (Melhole.View.Input item);
                                   (match __melhole_changed_0 with
                                    | Melhole.View.Unchanged -> ()
                                    | _ ->
                                        Melhole.View.write_sole_text
                                          __melhole_hole_0 (item : string));
                                   ())
                                 [@ocaml.warning "-26-27"]))
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
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let __melhole_hook_1 =
    (Melact_runtime.Hook.key () : unit Melact_runtime.Hook.key)
  let useToggle () =
    (React.useState (Melact_runtime.Hook.unchecked __melhole_hook_1))
      (fun () -> false)
  let __melhole_component_2 = Melact_runtime.Component.make ~name:"Hooks.make"
  include
    struct
      type make_props =
        | Make_props of React.element [@@unboxed ]
      let __melhole_hook_3 =
        (Melact_runtime.Hook.key () : unit Melact_runtime.Hook.key)
      let makeProps ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melact_runtime.Instance.component __melhole_component_2 [||]
               (fun () ->
                  React.to_child
                    (let (shown, _) = useToggle () in
                     (React.useEffect1
                        (Melact_runtime.Hook.unchecked __melhole_hook_3))
                       ((fun () -> None)[@alert "+hook"]) [|shown|];
                     React.string (React.useContext Theme.context)))) in
        Make_props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : make_props -> React.element = "%identity"
    end

Reason input:

  $ cat > greeting.re <<'EOF'
  > [@react.component]
  > let make = (~name) => <span className="greeting"> {React.string("Hello, " ++ name)} </span>;
  > EOF
  $ refmt --print ml greeting.re > greeting.ml
  $ ./pp.exe -impl greeting.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let __melhole_component_1 =
    Melact_runtime.Component.make ~name:"Greeting.make"
  include
    struct
      type make_props =
        | Make_props of React.element [@@unboxed ]
      type 'melhole_0 __melhole_frame_2 =
        {
        __melhole_frame_2_hole_0: 'melhole_0 ;
        mutable __melhole_frame_2_slot_0: Melhole.View.input ;
        mutable __melhole_frame_2_slot_1: Melhole.View.input }[@@ocaml.warning
                                                                "-34-69"]
      let __melhole_template_3 =
        Melhole.View.template
          (Melhole.Template.html "<span class=\"greeting\"></span>")
          {
            Js.Fn.I1 =
              (fun __melhole_node ->
                 {
                   __melhole_frame_2_hole_0 =
                     (Melhole.Template.element __melhole_node);
                   __melhole_frame_2_slot_0 = Melhole.View.unset;
                   __melhole_frame_2_slot_1 = Melhole.View.unset
                 })
          }
          {
            Melhole.View.placed = None;
            released = None;
            forgotten =
              (Some
                 {
                   Js.Fn.I1 =
                     (fun __melhole_frame ->
                        __melhole_frame.__melhole_frame_2_slot_0 <-
                          (Melhole.View.Input Melhole.View.unset);
                        __melhole_frame.__melhole_frame_2_slot_1 <-
                          (Melhole.View.Input Melhole.View.unset))
                 })
          }
      let makeProps ~name:(name as __melhole_prop_0) ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_1
               [|(Melhole.View.Input __melhole_prop_0)|]
               (fun () ->
                  React.to_child
                    (React.of_child
                       (Melhole.View.compiled __melhole_template_3
                          {
                            Js.Fn.I1 =
                              (fun __melhole_frame ->
                                 ((let __melhole_hole_0 =
                                     __melhole_frame.__melhole_frame_2_hole_0 in
                                   let __melhole_changed_0 =
                                     Melhole.View.check
                                       __melhole_frame.__melhole_frame_2_slot_0
                                       name in
                                   __melhole_frame.__melhole_frame_2_slot_0 <-
                                     (Melhole.View.Input name);
                                   (match __melhole_changed_0 with
                                    | Melhole.View.Unchanged -> ()
                                    | _ ->
                                        let __melhole_value =
                                          ("Hello, " ^ name : string) in
                                        (Melhole.View.put_sole_text
                                           __melhole_frame.__melhole_frame_2_slot_1
                                           __melhole_hole_0 __melhole_value;
                                         __melhole_frame.__melhole_frame_2_slot_1
                                           <-
                                           (Melhole.View.Input __melhole_value)));
                                   ())
                                 [@ocaml.warning "-26-27"]))
                          })))) in
        Make_props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : make_props -> React.element = "%identity"[@@melhole.inline
                                                                 (1,
                                                                   (fun ~name
                                                                      ->
                                                                      ((
                                                                      span
                                                                      ~className:"greeting"
                                                                      ~children:
                                                                      [
                                                                      React.string
                                                                      ("Hello, "
                                                                      ^ name)]
                                                                      ())
                                                                      [@JSX ])))]
    end

mlx input:

  $ cat > greeting.mlx <<'EOF'
  > let[@react.component] make ~name =
  >   <span className="greeting">(React.string ("Hello, " ^ name))</span>
  > EOF
  $ mlx-pp greeting.mlx > greeting.ast
  $ ./pp.exe -impl greeting.ast
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let __melhole_component_1 =
    Melact_runtime.Component.make ~name:"Greeting.make"
  include
    struct
      type make_props =
        | Make_props of React.element [@@unboxed ]
      type 'melhole_0 __melhole_frame_2 =
        {
        __melhole_frame_2_hole_0: 'melhole_0 ;
        mutable __melhole_frame_2_slot_0: Melhole.View.input ;
        mutable __melhole_frame_2_slot_1: Melhole.View.input }[@@ocaml.warning
                                                                "-34-69"]
      let __melhole_template_3 =
        Melhole.View.template
          (Melhole.Template.html "<span class=\"greeting\"></span>")
          {
            Js.Fn.I1 =
              (fun __melhole_node ->
                 {
                   __melhole_frame_2_hole_0 =
                     (Melhole.Template.element __melhole_node);
                   __melhole_frame_2_slot_0 = Melhole.View.unset;
                   __melhole_frame_2_slot_1 = Melhole.View.unset
                 })
          }
          {
            Melhole.View.placed = None;
            released = None;
            forgotten =
              (Some
                 {
                   Js.Fn.I1 =
                     (fun __melhole_frame ->
                        __melhole_frame.__melhole_frame_2_slot_0 <-
                          (Melhole.View.Input Melhole.View.unset);
                        __melhole_frame.__melhole_frame_2_slot_1 <-
                          (Melhole.View.Input Melhole.View.unset))
                 })
          }
      let makeProps ~name:(name as __melhole_prop_0) ?key:__melhole_key () =
        let __melhole_element =
          React.of_child
            (Melhole.View.pure __melhole_component_1
               [|(Melhole.View.Input __melhole_prop_0)|]
               (fun () ->
                  React.to_child
                    (React.of_child
                       (Melhole.View.compiled __melhole_template_3
                          {
                            Js.Fn.I1 =
                              (fun __melhole_frame ->
                                 ((let __melhole_hole_0 =
                                     __melhole_frame.__melhole_frame_2_hole_0 in
                                   let __melhole_changed_0 =
                                     Melhole.View.check
                                       __melhole_frame.__melhole_frame_2_slot_0
                                       name in
                                   __melhole_frame.__melhole_frame_2_slot_0 <-
                                     (Melhole.View.Input name);
                                   (match __melhole_changed_0 with
                                    | Melhole.View.Unchanged -> ()
                                    | _ ->
                                        let __melhole_value =
                                          ("Hello, " ^ name : string) in
                                        (Melhole.View.put_sole_text
                                           __melhole_frame.__melhole_frame_2_slot_1
                                           __melhole_hole_0 __melhole_value;
                                         __melhole_frame.__melhole_frame_2_slot_1
                                           <-
                                           (Melhole.View.Input __melhole_value)));
                                   ())
                                 [@ocaml.warning "-26-27"]))
                          })))) in
        Make_props
          (match __melhole_key with
           | None -> __melhole_element
           | Some key ->
               React.of_child
                 (Melhole.View.with_key key (React.to_child __melhole_element)))
      external make : make_props -> React.element = "%identity"[@@melhole.inline
                                                                 (1,
                                                                   (fun ~name
                                                                      ->
                                                                      ((
                                                                      span ()
                                                                      ~children:
                                                                      [
                                                                      React.string
                                                                      ("Hello, "
                                                                      ^ name)]
                                                                      ~className:"greeting")
                                                                      [@JSX ])))]
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
  58:                       ((fun () -> 0)[@alert "+hook"]) in
  61:                     then ((1)[@alert "+hook"])
  62:                     else ((0)[@alert "+hook"]) in
  102:                                                   [@alert "+hook"]))
  103:                                               [@alert "+hook"])

Values written in props are cached as an expression whose first branch returns the kept value,
so the type the prop expects reaches the value in the branch that stores it, and the bare
constructors and labels of a type declared in a module that is not opened resolve; a value that
reads mutable state while rendering is left as written:

  $ cat > props.ml <<'EOF'
  > let make () =
  >   let n, _ = React.useState (fun () -> 0) in
  >   ((Box.createElement ~style:{ pad = n; tone = Strong 1 } ~tone:Soft ~pick:(fun () -> Strong n)
  >       ~pair:(Soft, !Box.outside) ~children:[] ()) [@JSX])
  > [@@react.component]
  > EOF
  $ ./pp.exe -impl props.ml | sed -n '/Box.make/,/())))) in/p'
                     Box.make
                       (Box.makeProps
                          ~style:(let __melact_found =
                                    Melact_runtime.Memo.lookup1 __melact_memo 0
                                      n in
                                  match Melact_runtime.Memo.kept __melact_found
                                  with
                                  | Some __melact_kept -> ((__melact_kept)
                                      [@alert "+hook"])
                                  | None ->
                                      ((Melact_runtime.Memo.store __melact_memo
                                          1 __melact_found
                                          { pad = n; tone = (Strong 1) })
                                      [@alert "+hook"])) ~tone:Soft
                          ~pick:(let __melact_found =
                                   Melact_runtime.Memo.lookup1 __melact_memo 2
                                     n in
                                 match Melact_runtime.Memo.kept __melact_found
                                 with
                                 | Some __melact_kept -> ((__melact_kept)
                                     [@alert "+hook"])
                                 | None ->
                                     ((Melact_runtime.Memo.store __melact_memo
                                         3 __melact_found ((fun () -> Strong n)
                                         [@alert "+hook"]))
                                     [@alert "+hook"]))
                          ~pair:(Soft, (!Box.outside)) ())))) in

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
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let melact_key_useEffect3 = Melact_runtime.Hook.key ()[@@warning "-32"]
  let useEffect3 _melact_argument_0 _melact_argument_1 =
    React.useEffect3 (Melact_runtime.Hook.unchecked melact_key_useEffect3)
      _melact_argument_0 _melact_argument_1[@@warning "-32"]
  let melact_key_useEffect8 = Melact_runtime.Hook.key ()[@@warning "-32"]
  let useEffect8 _melact_argument_0 _melact_argument_1 =
    React.useEffect1 (Melact_runtime.Hook.unchecked melact_key_useEffect8)
      _melact_argument_0 _melact_argument_1[@@warning "-32"]
  let __melhole_hook_1 =
    (Melact_runtime.Hook.key () : unit Melact_runtime.Hook.key)
  let __melhole_hook_2 =
    (Melact_runtime.Hook.key () : unit Melact_runtime.Hook.key)
  let use a =
    (React.useEffect3 (Melact_runtime.Hook.unchecked __melhole_hook_1))
      (fun () -> None) (a, "x", 1.0);
    (React.useEffect1 (Melact_runtime.Hook.unchecked __melhole_hook_2))
      (fun () -> None) [|a;1;2;3;4;5;6;7|]

A tuple longer than the numbered hooks take is passed as the array it is in JavaScript, and uses
call the binding's definition:

  $ cat > long.ml <<'EOF'
  > external useMemo8 : (unit -> 'v) -> 'a * 'b * 'c * 'd * 'e * 'f * 'g * 'h -> 'v = "useMemo" [@@mel.module "react"]
  > let use a = useMemo8 (fun () -> a) (a, 1, 2, 3, 4, 5, 6, "x")
  > EOF
  $ ./pp.exe -impl long.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let melact_key_useMemo8 = Melact_runtime.Hook.key ()[@@warning "-32"]
  let useMemo8 _melact_argument_0 _melact_argument_1 =
    React.useMemo1 (Melact_runtime.Hook.unchecked melact_key_useMemo8)
      _melact_argument_0 (Melact_runtime.Hook.listed _melact_argument_1)
    [@@warning "-32"]
  let use a = useMemo8 (fun () -> a) (a, 1, 2, 3, 4, 5, 6, "x")

Bindings to npm React's element functions that return a React.element become Melact's elements: a
string tag builds a DOM element from the props object, a component is called with its props:

  $ cat > elements.ml <<'EOF'
  > external createElement : string -> < .. > Js.t -> React.element = "createElement" [@@mel.module "react"]
  > external jsx : string -> < .. > Js.t -> ?key:string -> unit -> React.element = "jsx" [@@mel.module "react/jsx-runtime"]
  > type real
  > external own : string -> < .. > Js.t -> real = "createElement" [@@mel.module "react"]
  > let make () = createElement "h1" [%mel.obj { id = "x" }]
  > EOF
  $ ./pp.exe -impl elements.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  let createElement _melact_argument_0 _melact_argument_1 =
    Melact_npm.created _melact_argument_0 _melact_argument_1 [||][@@warning
                                                                   "-32"]
  let jsx _melact_argument_0 _melact_argument_1 ?key:_melact_argument_2
    _melact_argument_3 =
    Melact_npm.keyed
      (Melact_npm.created _melact_argument_0 _melact_argument_1 [||])
      _melact_argument_2[@@warning "-32"]
  type real
  external own : string -> < .. >  Js.t -> real = "createElement"[@@mel.module
                                                                   "react"]
  let make () = createElement "h1" ([%mel.obj { id = "x" }])

A binding to npm's Fragment with a type of its own is left alone:

  $ cat > fragment.ml <<'EOF'
  > type elementType
  > external fragmentType : elementType = "Fragment" [@@mel.module "react"]
  > let a = fragmentType
  > EOF
  $ ./pp.exe -impl fragment.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  type elementType
  external fragmentType : elementType = "Fragment"[@@mel.module "react"]
  let a = fragmentType

A [@react.component] external binds a component of a JavaScript React library, which Melact cannot
render, and says so:

  $ cat > external.ml <<'EOF'
  > module Ext = struct
  >   external make : src:string -> loop:bool -> React.element = "Thing" [@@mel.module "some-lib"] [@@react.component]
  > end
  > EOF
  $ ./pp.exe -impl external.ml
  File "external.ml", line 2, characters 2-114:
  2 |   external make : src:string -> loop:bool -> React.element = "Thing" [@@mel.module "some-lib"] [@@react.component]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: melact: [@react.component] external binds a component of a JavaScript React library. It is React code and needs React itself to render; Melact cannot run it. Write the component in Reason or OCaml, or keep this part of the app on reason-react.
  [1]

Lists in the forms reason-react code writes them, piped or not, compile to keyed loops, also Reason's
`items->Belt.Array.map(f)->React.array`, which refmt parses as `(items |. Belt.Array.map) f` and
melange.ppx may turn into `(Belt.Array.map items) f`; a row that reads its index is numbered, one
that ignores it is not:

  $ cat > forms.ml <<'EOF'
  > let piped items = ((ul ~children:[ items |. Belt.Array.map (fun x -> ((Row.createElement ~key:x ~v:x ~children:[] ()) [@JSX])) |. React.array ] ()) [@JSX])
  > let last items = ((ul ~children:[ items |> Array.map (fun x -> ((Row.createElement ~key:x ~v:x ~children:[] ()) [@JSX])) |> React.array ] ()) [@JSX])
  > let labelled items = ((ul ~children:[ items |. Js.Array.map ~f:(fun x -> ((Row.createElement ~key:x ~v:x ~children:[] ()) [@JSX])) |. React.array ] ()) [@JSX])
  > let numbered items = ((ul ~children:[ Array.mapi (fun i x -> ((Row.createElement ~key:x ~v:i ~children:[] ()) [@JSX])) items |. React.array ] ()) [@JSX])
  > let belt_numbered items = ((ul ~children:[ items |. Belt.Array.mapWithIndex (fun i x -> ((Row.createElement ~key:x ~v:i ~children:[] ()) [@JSX])) |. React.array ] ()) [@JSX])
  > let js_numbered items = ((ul ~children:[ items |. Js.Array.mapi ~f:(fun x i -> ((Row.createElement ~key:x ~v:i ~children:[] ()) [@JSX])) |. React.array ] ()) [@JSX])
  > let unused items = ((ul ~children:[ Array.mapi (fun _ x -> ((Row.createElement ~key:x ~v:x ~children:[] ()) [@JSX])) items |. React.array ] ()) [@JSX])
  > let reason items = ((ul ~children:[ ((items |. Belt.Array.map) (fun x -> ((Row.createElement ~key:x ~v:x ~children:[] ()) [@JSX]))) |. React.array ] ()) [@JSX])
  > let reason_numbered items = ((ul ~children:[ ((items |. Belt.Array.mapWithIndex) (fun i x -> ((Row.createElement ~key:x ~v:i ~children:[] ()) [@JSX]))) |. React.array ] ()) [@JSX])
  > let reason_desugared items = ((ul ~children:[ React.array ((Belt.Array.map items) (fun x -> ((Row.createElement ~key:x ~v:x ~children:[] ()) [@JSX]))) ] ()) [@JSX])
  > let branched wide items = ((ul ~children:[ (match wide with true -> React.null | false -> React.array (Array.map (fun x -> ((Row.createElement ~key:x ~v:x ~children:[] ()) [@JSX])) items)) ] ()) [@JSX])
  > let chosen wide items = ((ul ~children:[ (if wide then React.null else React.array (Array.mapi (fun i x -> ((Row.createElement ~key:x ~v:i ~children:[] ()) [@JSX])) items)) ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl forms.ml | grep -o "Melhole.View.Items\\|Melhole.View.Numbered"
  Melhole.View.Items
  Melhole.View.Items
  Melhole.View.Items
  Melhole.View.Numbered
  Melhole.View.Numbered
  Melhole.View.Numbered
  Melhole.View.Items
  Melhole.View.Items
  Melhole.View.Numbered
  Melhole.View.Items
  Melhole.View.Items
  Melhole.View.Numbered

A row function bound by a let in a component is cached and still compiles to a loop:

  $ cat > letrow.ml <<'EOF'
  > let make ~items =
  >   let chosen, setChosen = React.useState (fun () -> "") in
  >   let row item = ((li ~key:item ~className:(if item = chosen then "on" else "") ~onClick:(fun _ -> setChosen (fun _ -> item)) ~children:[ React.string item ] ()) [@JSX]) in
  >   ((ul ~children:[ React.array (Array.map row items) ] ()) [@JSX])
  > [@@react.component]
  > EOF
  $ ./pp.exe -impl letrow.ml | grep -o "Memo.lookup2\|Melhole.View.rows\|melhole.cached"
  Memo.lookup2
  Melhole.View.rows

A row whose prop picks it by key gets a selector, in a numbered loop too, where the key can be the
index:

  $ cat > selected.ml <<'EOF'
  > let make ~items ~chosen = ((ul ~children:[ Array.mapi (fun i x -> ((Row.createElement ~key:x ~tone:(match chosen with Some k when k = i -> "on" | _ -> "") ~children:[] ()) [@JSX])) items |. React.array ] ()) [@JSX])
  > [@@react.component]
  > let plain ~items ~chosen = ((ul ~children:[ items |. Belt.Array.map (fun x -> ((Row.createElement ~key:x ~tone:(if x = chosen then "on" else "") ~children:[] ()) [@JSX])) |. React.array ] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl selected.ml | tr -s ' \n' ' ' | grep -o "Melhole.View.each __melhole_site_[0-9]* Melhole.View.[A-Za-z]*\|Melhole.View.selector Melhole.View.[A-Za-z]*\|Js.Fn.I2 = (fun __melhole_item __melhole_index -> ((let [^}]*"
  Melhole.View.each __melhole_site_3 Melhole.View.Numbered
  Melhole.View.selector Melhole.View.Structural
  Js.Fn.I2 = (fun __melhole_item __melhole_index -> ((let i = __melhole_index in let x = __melhole_item in i) [@ocaml.warning "-26-27"])) 
  Melhole.View.each __melhole_site_7 Melhole.View.Items
  Melhole.View.selector Melhole.View.Structural
  Js.Fn.I2 = (fun __melhole_item __melhole_index -> ((let x = __melhole_item in x) [@ocaml.warning "-26-27"])) 

A component without hooks of the same file is spliced into the row of a list and into a child slot,
so the list compiles to rows of one template; an element that flows as a value keeps the component:

  $ cat > inlined.ml <<'EOF'
  > module Row = struct
  >   let make = React.memo (fun ~item -> ((li ~children:[ React.string item ] ()) [@JSX])) [@@react.component]
  > end
  > let rows items = ((ul ~children:[ React.array (Array.map (fun item -> ((Row.createElement ~key:item ~item ~children:[] ()) [@JSX])) items) ] ()) [@JSX])
  > let slot = ((ul ~children:[ ((Row.createElement ~item:"a" ~children:[] ()) [@JSX]) ] ()) [@JSX])
  > let value = ((Row.createElement ~item:"b" ~children:[] ()) [@JSX])
  > EOF
  $ ./pp.exe -impl inlined.ml | grep -o "Melhole.View.rows\|Melhole.View.each\|Row.makeProps"
  Melhole.View.rows
  Row.makeProps
