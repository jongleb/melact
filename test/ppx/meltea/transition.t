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
    mutable __melhole_frame_1_slot_0: Meltea_runtime.View.input ;
    mutable __melhole_frame_1_slot_1: Meltea_runtime.View.input ;
    mutable __melhole_frame_1_slot_2: Meltea_runtime.View.input }[@@ocaml.warning
                                                                   "-34-69"]
  let __melhole_selection_3 = Meltea_runtime.View.selection 1
  type 'melhole_0 __melhole_frame_4 =
    {
    __melhole_frame_4_root: 'melhole_0 ;
    mutable __melhole_frame_4_slot_0: Meltea_runtime.View.input ;
    mutable __melhole_frame_4_slot_1: Meltea_runtime.View.input ;
    mutable __melhole_frame_4_slot_2: Meltea_runtime.View.input }[@@ocaml.warning
                                                                   "-34-69"]
  let __melhole_template_5 =
    Meltea_runtime.View.template (Melhole.Template.html "<li></li>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             {
               __melhole_frame_4_root =
                 (Melhole.Template.element __melhole_node);
               __melhole_frame_4_slot_0 = Meltea_runtime.View.unset;
               __melhole_frame_4_slot_1 = Meltea_runtime.View.unset;
               __melhole_frame_4_slot_2 = Meltea_runtime.View.unset
             })
      }
      { Meltea_runtime.View.placed = None; released = None; forgotten = None }
  let __melhole_root_6 =
    {
      Js.Fn.I1 =
        (fun __melhole_frame -> __melhole_frame.__melhole_frame_4_root)
    }
  type 'melhole_0 __melhole_frame_7 = {
    __melhole_frame_7_hole_0: 'melhole_0 }[@@ocaml.warning "-34-69"]
  let __melhole_template_8 =
    Meltea_runtime.View.template (Melhole.Template.html "<ul></ul>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             {
               __melhole_frame_7_hole_0 =
                 (Meltea_runtime.View.content_hole
                    {
                      Melhole.Template.parent = __melhole_node;
                      before = (Melhole.Template.first_or_end __melhole_node)
                    })
             })
      }
      {
        Meltea_runtime.View.placed = None;
        released =
          (Some
             {
               Js.Fn.I1 =
                 (fun __melhole_frame ->
                    Meltea_runtime.View.release_content
                      __melhole_frame.__melhole_frame_7_hole_0)
             });
        forgotten = None
      }
  let view (rows, chosen) =
    Html.node
      (fun __melhole_dispatch ->
         Meltea_runtime.View.compiled __melhole_template_8
           {
             Js.Fn.I1 =
               (fun __melhole_frame ->
                  ((let __melhole_hole_0 =
                      __melhole_frame.__melhole_frame_7_hole_0 in
                    Meltea_runtime.View.set_content __melhole_hole_0
                      (Meltea_runtime.Transition.group ~name:"row"
                         ~duration:200
                         (Meltea_runtime.View.rows rows Stdlib.Array.of_list
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
                                         Meltea_runtime.View.check
                                           __melhole_frame.__melhole_frame_4_slot_0
                                           chosen in
                                       __melhole_frame.__melhole_frame_4_slot_0
                                         <- (Meltea_runtime.View.Input chosen);
                                       (let __melhole_changed_1 =
                                          Meltea_runtime.View.check
                                            __melhole_frame.__melhole_frame_4_slot_1
                                            id in
                                        __melhole_frame.__melhole_frame_4_slot_1
                                          <- (Meltea_runtime.View.Input id);
                                        if
                                          (__melhole_changed_0 ==
                                             Meltea_runtime.View.Changed)
                                            ||
                                            (__melhole_changed_1 ==
                                               Meltea_runtime.View.Changed)
                                        then
                                          (let __melhole_value =
                                             Some
                                               (if id = chosen
                                                then "on"
                                                else "" : string) in
                                           Meltea_runtime.View.put_attr
                                             __melhole_frame.__melhole_frame_4_slot_2
                                             __melhole_hole_0 "class"
                                             __melhole_value;
                                           __melhole_frame.__melhole_frame_4_slot_2
                                             <-
                                             (Meltea_runtime.View.Input
                                                __melhole_value));
                                        if
                                          __melhole_changed_1 ==
                                            Meltea_runtime.View.Changed
                                        then
                                          Meltea_runtime.View.write_sole_text
                                            __melhole_hole_1
                                            (Melhole.Dom_api.shown_int id);
                                        ()))
                                       [@ocaml.warning "-26-27"]))
                                   [@ocaml.warning "-26-27"]))
                            }
                            {
                              Js.Fn.I1 =
                                (fun __melhole_item ->
                                   ((let id = __melhole_item in
                                     Melhole.Reconcile.int_key id)
                                   [@ocaml.warning "-26-27"]))
                            } Meltea_runtime.View.scans
                            {
                              Js.Fn.I4 =
                                (fun __melhole_item __melhole_index
                                   __melhole_out __melhole_at ->
                                   ((let id = __melhole_item in
                                     Stdlib.Array.unsafe_set __melhole_out
                                       (__melhole_at + 0)
                                       (Meltea_runtime.View.Input
                                          __melhole_dispatch);
                                     Stdlib.Array.unsafe_set __melhole_out
                                       (__melhole_at + 1)
                                       (Meltea_runtime.View.Input
                                          (if id = chosen then "on" else ""));
                                     ())
                                   [@ocaml.warning "-26-27"]))
                            } 2
                            [|(Meltea_runtime.View.Input __melhole_dispatch);(
                              Meltea_runtime.View.Input chosen)|]
                            (Meltea_runtime.View.Selecting
                               (__melhole_selection_3,
                                 [|(Meltea_runtime.View.selector
                                      Meltea_runtime.View.Structural
                                      (Some chosen)
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
    mutable __melhole_frame_1_slot_0: Meltea_runtime.View.input }[@@ocaml.warning
                                                                   "-34-69"]
  let __melhole_template_2 =
    Meltea_runtime.View.hydratable
      (Melhole.Template.html "<p>count: <b>!</b></p>")
      {
        Js.Fn.I1 =
          (fun __melhole_node ->
             let __melhole_node_0 = Melhole.Template.first __melhole_node in
             {
               __melhole_frame_1_hole_0 =
                 (Meltea_runtime.View.text_at
                    {
                      Melhole.Template.parent = __melhole_node;
                      before = (Melhole.Template.next_or_end __melhole_node_0)
                    });
               __melhole_frame_1_slot_0 = Meltea_runtime.View.unset
             })
      }
      { Meltea_runtime.View.placed = None; released = None; forgotten = None }
      {
        Js.Fn.I2 =
          (fun __melhole_node __melhole_collect ->
             ((let __melhole_collected = __melhole_collect () in
               let __melhole_from__melhole_hole_0 =
                 __melhole_collected.__melhole_frame_1_hole_0 in
               let __melhole_cursor = Meltea_runtime.View.inside __melhole_node in
               Meltea_runtime.View.adopt_static __melhole_cursor "count: ";
               (let __melhole_hole_0 =
                  Meltea_runtime.View.adopt_text __melhole_cursor
                    (Meltea_runtime.View.collected_text
                       __melhole_from__melhole_hole_0) in
                let __melhole_node_1 =
                  Meltea_runtime.View.adopt_element __melhole_cursor "b" in
                let __melhole_cursor_1 =
                  Meltea_runtime.View.inside __melhole_node_1 in
                Meltea_runtime.View.adopt_static __melhole_cursor_1 "!";
                Meltea_runtime.View.adopt_finish __melhole_cursor_1;
                Meltea_runtime.View.adopt_finish __melhole_cursor;
                {
                  __melhole_frame_1_hole_0 = __melhole_hole_0;
                  __melhole_frame_1_slot_0 = Meltea_runtime.View.unset
                }))
             [@ocaml.warning "-26-27"]))
      }
  let view count =
    Html.node
      (fun __melhole_dispatch ->
         Meltea_runtime.View.compiled __melhole_template_2
           {
             Js.Fn.I1 =
               (fun __melhole_frame ->
                  ((let __melhole_hole_0 =
                      __melhole_frame.__melhole_frame_1_hole_0 in
                    let __melhole_changed_0 =
                      Meltea_runtime.View.check
                        __melhole_frame.__melhole_frame_1_slot_0 count in
                    __melhole_frame.__melhole_frame_1_slot_0 <-
                      (Meltea_runtime.View.Input count);
                    if __melhole_changed_0 == Meltea_runtime.View.Changed
                    then
                      Meltea_runtime.View.served_write_text __melhole_hole_0
                        (string_of_int (count : int));
                    ())
                  [@ocaml.warning "-26-27"]))
           })
  let __melhole_reads_view = Program.Reads { analysed = view; fields = (-1) }
