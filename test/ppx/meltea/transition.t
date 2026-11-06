A list inside Html.transition_group is still the keyed loop with selectors, inside the wrapper:

  $ cat > rows.ml <<'EOF_'
  > let view (rows, chosen) =
  >   let row id = ((li ~key:(string_of_int id) ~className:(if id = chosen then "on" else "") ~children:[ Html.int id ] ()) [@JSX]) in
  >   ((ul ~children:[ Html.transition_group ~name:"row" ~duration:200 (Html.list (List.map row rows)) ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -impl rows.ml
  type 'melhole_0 __melhole_frame_1 =
    {
    __melhole_frame_1_hole_0: 'melhole_0 ;
    mutable __melhole_frame_1_slot_0: Melhole.View.input ;
    mutable __melhole_frame_1_slot_1: Melhole.View.input ;
    mutable __melhole_frame_1_slot_2: Melhole.View.input }[@@ocaml.warning
                                                            "-34-69"]
  let __melhole_template_2 =
    Melhole.View.template (Melhole.Template.html "<li></li>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             {
               __melhole_frame_1_hole_0 =
                 (Melhole.Template.element __melhole_node);
               __melhole_frame_1_slot_0 = Melhole.View.unset;
               __melhole_frame_1_slot_1 = Melhole.View.unset;
               __melhole_frame_1_slot_2 = Melhole.View.unset
             })
      } { Melhole.View.placed = None; released = None; forgotten = None }
  let __melhole_selection_3 = Melhole.View.selection 1
  type 'melhole_0 __melhole_frame_4 =
    {
    __melhole_frame_4_root: 'melhole_0 ;
    mutable __melhole_frame_4_slot_0: Melhole.View.input ;
    mutable __melhole_frame_4_slot_1: Melhole.View.input ;
    mutable __melhole_frame_4_slot_2: Melhole.View.input }[@@ocaml.warning
                                                            "-34-69"]
  let __melhole_template_5 =
    Melhole.View.template (Melhole.Template.html "<li></li>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             {
               __melhole_frame_4_root =
                 (Melhole.Template.element __melhole_node);
               __melhole_frame_4_slot_0 = Melhole.View.unset;
               __melhole_frame_4_slot_1 = Melhole.View.unset;
               __melhole_frame_4_slot_2 = Melhole.View.unset
             })
      } { Melhole.View.placed = None; released = None; forgotten = None }
  let __melhole_root_6 =
    {
      Js.Fn.I1 =
        (fun __melhole_frame -> __melhole_frame.__melhole_frame_4_root)
    }
  type 'melhole_0 __melhole_frame_7 = {
    __melhole_frame_7_hole_0: 'melhole_0 }[@@ocaml.warning "-34-69"]
  let __melhole_template_8 =
    Melhole.View.template (Melhole.Template.html "<ul></ul>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             {
               __melhole_frame_7_hole_0 =
                 (Melhole.View.content_hole
                    {
                      Melhole.Template.parent = __melhole_node;
                      before = (Melhole.Template.first_or_end __melhole_node)
                    })
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
                      __melhole_frame.__melhole_frame_7_hole_0)
             });
        forgotten = None
      }
  let view (rows, chosen) =
    let row id =
      Html.node
        (fun __melhole_dispatch ->
           Melhole.View.with_key (string_of_int id : string)
             (Html.render
                (Html.node
                   (fun __melhole_dispatch ->
                      Melhole.View.compiled __melhole_template_2
                        {
                          Js.Fn.I1 =
                            (fun __melhole_frame ->
                               ((let __melhole_hole_0 =
                                   __melhole_frame.__melhole_frame_1_hole_0 in
                                 let __melhole_hole_1 = __melhole_hole_0 in
                                 let __melhole_changed_0 =
                                   Melhole.View.check
                                     __melhole_frame.__melhole_frame_1_slot_0
                                     chosen in
                                 __melhole_frame.__melhole_frame_1_slot_0 <-
                                   (Melhole.View.Input chosen);
                                 (let __melhole_changed_1 =
                                    Melhole.View.check
                                      __melhole_frame.__melhole_frame_1_slot_1
                                      id in
                                  __melhole_frame.__melhole_frame_1_slot_1 <-
                                    (Melhole.View.Input id);
                                  (match (__melhole_changed_0,
                                           __melhole_changed_1)
                                   with
                                   | (Melhole.View.Unchanged,
                                      Melhole.View.Unchanged) -> ()
                                   | _ ->
                                       let __melhole_value =
                                         Some
                                           (if id = chosen then "on" else "" : 
                                           string) in
                                       (Melhole.View.put_attr
                                          __melhole_frame.__melhole_frame_1_slot_2
                                          __melhole_hole_0 "class"
                                          __melhole_value;
                                        __melhole_frame.__melhole_frame_1_slot_2
                                          <-
                                          (Melhole.View.Input __melhole_value)));
                                  (match __melhole_changed_1 with
                                   | Melhole.View.Unchanged -> ()
                                   | _ ->
                                       Melhole.View.write_sole_text
                                         __melhole_hole_1
                                         (string_of_int (id : int)));
                                  ()))
                               [@ocaml.warning "-26-27"]))
                        })) __melhole_dispatch)) in
    Html.node
      (fun __melhole_dispatch ->
         Melhole.View.compiled __melhole_template_8
           {
             Js.Fn.I1 =
               (fun __melhole_frame ->
                  ((let __melhole_hole_0 =
                      __melhole_frame.__melhole_frame_7_hole_0 in
                    Melhole.View.set_content __melhole_hole_0
                      (Melhole.Transition.group ~name:"row" ~duration:200
                         (let _ = row in
                          Melhole.View.rows (Stdlib.Array.of_list rows)
                            __melhole_template_5 __melhole_root_6
                            {
                              Js.Fn.I2 =
                                (fun __melhole_frame __melhole_item ->
                                   ((let id = __melhole_item in
                                     ((let __melhole_root =
                                         __melhole_frame.__melhole_frame_4_root in
                                       let __melhole_hole_0 = __melhole_root in
                                       let __melhole_hole_1 = __melhole_root in
                                       let __melhole_changed_0 =
                                         Melhole.View.check
                                           __melhole_frame.__melhole_frame_4_slot_0
                                           chosen in
                                       __melhole_frame.__melhole_frame_4_slot_0
                                         <- (Melhole.View.Input chosen);
                                       (let __melhole_changed_1 =
                                          Melhole.View.check
                                            __melhole_frame.__melhole_frame_4_slot_1
                                            id in
                                        __melhole_frame.__melhole_frame_4_slot_1
                                          <- (Melhole.View.Input id);
                                        (match (__melhole_changed_0,
                                                 __melhole_changed_1)
                                         with
                                         | (Melhole.View.Unchanged,
                                            Melhole.View.Unchanged) -> ()
                                         | _ ->
                                             let __melhole_value =
                                               Some
                                                 (if id = chosen
                                                  then "on"
                                                  else "" : string) in
                                             (Melhole.View.put_attr
                                                __melhole_frame.__melhole_frame_4_slot_2
                                                __melhole_hole_0 "class"
                                                __melhole_value;
                                              __melhole_frame.__melhole_frame_4_slot_2
                                                <-
                                                (Melhole.View.Input
                                                   __melhole_value)));
                                        (match __melhole_changed_1 with
                                         | Melhole.View.Unchanged -> ()
                                         | _ ->
                                             Melhole.View.write_sole_text
                                               __melhole_hole_1
                                               (string_of_int (id : int)));
                                        ()))
                                       [@ocaml.warning "-26-27"]))
                                   [@ocaml.warning "-26-27"]))
                            }
                            {
                              Js.Fn.I1 =
                                (fun __melhole_item ->
                                   ((let id = __melhole_item in
                                     (string_of_int id : string))
                                   [@ocaml.warning "-26-27"]))
                            }
                            {
                              Js.Fn.I4 =
                                (fun __melhole_item __melhole_index
                                   __melhole_out __melhole_at ->
                                   ((let id = __melhole_item in
                                     Stdlib.Array.unsafe_set __melhole_out
                                       (__melhole_at + 0)
                                       (Melhole.View.Input __melhole_dispatch);
                                     Stdlib.Array.unsafe_set __melhole_out
                                       (__melhole_at + 1)
                                       (Melhole.View.Input
                                          (if id = chosen then "on" else ""));
                                     ())
                                   [@ocaml.warning "-26-27"]))
                            } 2
                            [|(Melhole.View.Input __melhole_dispatch);(
                              Melhole.View.Input chosen)|]
                            (Melhole.View.Selecting
                               (__melhole_selection_3,
                                 [|(Melhole.View.selector
                                      Melhole.View.Structural (Some chosen)
                                      {
                                        Js.Fn.I2 =
                                          (fun __melhole_item __melhole_index
                                             ->
                                             ((let id = __melhole_item in id)
                                             [@ocaml.warning "-26-27"]))
                                      })|]))));
                    ())
                  [@ocaml.warning "-26-27"]))
           })

With -hydratable, every template also gets the code that takes over a server's nodes in document order:

  $ cat > counter.ml <<'EOF_'
  > let view count = ((p ~children:[ Html.text "count: "; Html.int count; ((b ~children:[ Html.text "!" ] ()) [@JSX]) ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -hydratable -impl counter.ml
  type 'melhole_0 __melhole_frame_1 =
    {
    __melhole_frame_1_hole_0: 'melhole_0 ;
    mutable __melhole_frame_1_slot_0: Melhole.View.input }[@@ocaml.warning
                                                            "-34-69"]
  let __melhole_template_2 =
    Melhole.View.hydratable (Melhole.Template.html "<p>count: <b>!</b></p>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             let __melhole_node_0 = Melhole.Template.first __melhole_node in
             {
               __melhole_frame_1_hole_0 =
                 (Melhole.View.text_at
                    {
                      Melhole.Template.parent = __melhole_node;
                      before = (Melhole.Template.next_or_end __melhole_node_0)
                    });
               __melhole_frame_1_slot_0 = Melhole.View.unset
             })
      } { Melhole.View.placed = None; released = None; forgotten = None }
      {
        Js.Fn.I2 =
          (fun __melhole_node __melhole_collected ->
             ((let __melhole_from__melhole_hole_0 =
                 __melhole_collected.__melhole_frame_1_hole_0 in
               let __melhole_cursor = Melhole.View.inside __melhole_node in
               Melhole.View.adopt_static __melhole_cursor "count: ";
               (let __melhole_hole_0 =
                  Melhole.View.adopt_text __melhole_cursor
                    (Melhole.View.collected_text __melhole_from__melhole_hole_0) in
                let __melhole_node_1 =
                  Melhole.View.adopt_element __melhole_cursor "b" in
                let __melhole_cursor_1 = Melhole.View.inside __melhole_node_1 in
                Melhole.View.adopt_static __melhole_cursor_1 "!";
                Melhole.View.adopt_finish __melhole_cursor_1;
                Melhole.View.adopt_finish __melhole_cursor;
                {
                  __melhole_frame_1_hole_0 = __melhole_hole_0;
                  __melhole_frame_1_slot_0 = Melhole.View.unset
                }))
             [@ocaml.warning "-26-27"]))
      }
  let view count =
    Html.node
      (fun __melhole_dispatch ->
         Melhole.View.compiled __melhole_template_2
           {
             Js.Fn.I1 =
               (fun __melhole_frame ->
                  ((let __melhole_hole_0 =
                      __melhole_frame.__melhole_frame_1_hole_0 in
                    let __melhole_changed_0 =
                      Melhole.View.check
                        __melhole_frame.__melhole_frame_1_slot_0 count in
                    __melhole_frame.__melhole_frame_1_slot_0 <-
                      (Melhole.View.Input count);
                    (match __melhole_changed_0 with
                     | Melhole.View.Unchanged -> ()
                     | _ ->
                         Melhole.Dom_api.set_data __melhole_hole_0
                           (string_of_int (count : int)));
                    ())
                  [@ocaml.warning "-26-27"]))
           })
  let __melhole_reads_view = Program.Reads { analysed = view; fields = (-1) }
