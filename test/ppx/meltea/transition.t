A list inside Html.transition_group is still the keyed loop with selectors, inside the wrapper:

  $ cat > rows.ml <<'EOF_'
  > let view (rows, chosen) =
  >   let row id = ((li ~key:(string_of_int id) ~className:(if id = chosen then "on" else "") ~children:[ Html.int id ] ()) [@JSX]) in
  >   ((ul ~children:[ Html.transition_group ~name:"row" ~duration:200 (Html.list (List.map row rows)) ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -impl rows.ml
  let __melhole_template_1 =
    Melhole.View.template (Melhole.Template.html "<li></li>")
      {
        Js.Fn.I2 =
          (fun __melhole_scope __melhole_node ->
             ((Melhole.Template.element __melhole_node),
               (Melhole.Template.element __melhole_node)))
      }
  let __melhole_template_2 =
    Melhole.View.template (Melhole.Template.html "<li></li>")
      {
        Js.Fn.I2 =
          (fun __melhole_scope __melhole_node ->
             ((Melhole.Template.element __melhole_node),
               (Melhole.Template.element __melhole_node)))
      }
  let __melhole_template_3 =
    Melhole.View.template (Melhole.Template.html "<ul></ul>")
      {
        Js.Fn.I2 =
          (fun __melhole_scope __melhole_node ->
             Melhole.View.content_hole __melhole_scope
               {
                 Melhole.Template.parent = __melhole_node;
                 before = (Melhole.Template.first_or_end __melhole_node)
               })
      }
  let view (rows, chosen) =
    let row id =
      Html.node
        (fun __melhole_dispatch ->
           Melhole.View.with_key (string_of_int id : string)
             (Html.render
                (Html.node
                   (fun __melhole_dispatch ->
                      Melhole.View.compiled __melhole_template_1 4
                        {
                          Js.Fn.I2 =
                            (fun __melhole_scope
                               (__melhole_hole_0, __melhole_hole_1) ->
                               let __melhole_changed_0 =
                                 Melhole.View.check __melhole_scope 0 chosen in
                               let __melhole_changed_1 =
                                 Melhole.View.check __melhole_scope 1 id in
                               (match (__melhole_changed_0,
                                        __melhole_changed_1)
                                with
                                | (Melhole.View.Unchanged,
                                   Melhole.View.Unchanged) -> ()
                                | _ ->
                                    Melhole.View.put_attr __melhole_scope 2
                                      __melhole_hole_0 "class"
                                      (Some
                                         (if id = chosen then "on" else "" : 
                                         string)));
                               (match __melhole_changed_1 with
                                | Melhole.View.Unchanged -> ()
                                | _ ->
                                    Melhole.View.put_sole_text __melhole_scope
                                      3 __melhole_hole_1
                                      (string_of_int (id : int)));
                               ())
                        })) __melhole_dispatch)) in
    Html.node
      (fun __melhole_dispatch ->
         Melhole.View.compiled __melhole_template_3 4
           {
             Js.Fn.I2 =
               (fun __melhole_scope __melhole_hole_0 ->
                  let __melhole_changed_0 =
                    Melhole.View.check __melhole_scope 0 __melhole_dispatch in
                  let __melhole_changed_1 =
                    Melhole.View.check __melhole_scope 1 chosen in
                  let __melhole_changed_2 =
                    Melhole.View.check __melhole_scope 2 row in
                  let __melhole_changed_3 =
                    Melhole.View.check __melhole_scope 3 rows in
                  (match (__melhole_changed_0, __melhole_changed_1,
                           __melhole_changed_2, __melhole_changed_3)
                   with
                   | (Melhole.View.Unchanged, Melhole.View.Unchanged,
                      Melhole.View.Unchanged, Melhole.View.Unchanged) -> ()
                   | _ ->
                       Melhole.View.set_content __melhole_hole_0
                         (Melhole.Transition.group ~name:"row" ~duration:200
                            (let _ = row in
                             Melhole.View.rows (Stdlib.Array.of_list rows)
                               __melhole_template_2 4
                               {
                                 Js.Fn.I3 =
                                   (fun __melhole_scope
                                      (__melhole_hole_0, __melhole_hole_1)
                                      __melhole_item ->
                                      ((let id = __melhole_item in
                                        let __melhole_changed_0 =
                                          Melhole.View.check __melhole_scope 0
                                            chosen in
                                        let __melhole_changed_1 =
                                          Melhole.View.check __melhole_scope 1
                                            id in
                                        (match (__melhole_changed_0,
                                                 __melhole_changed_1)
                                         with
                                         | (Melhole.View.Unchanged,
                                            Melhole.View.Unchanged) -> ()
                                         | _ ->
                                             Melhole.View.put_attr
                                               __melhole_scope 2
                                               __melhole_hole_0 "class"
                                               (Some
                                                  (if id = chosen
                                                   then "on"
                                                   else "" : string)));
                                        (match __melhole_changed_1 with
                                         | Melhole.View.Unchanged -> ()
                                         | _ ->
                                             Melhole.View.put_sole_text
                                               __melhole_scope 3
                                               __melhole_hole_1
                                               (string_of_int (id : int)));
                                        ())
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
                                 Js.Fn.I1 =
                                   (fun __melhole_item ->
                                      ((let id = __melhole_item in
                                        [|(Melhole.View.Input
                                             __melhole_dispatch);(Melhole.View.Input
                                                                    (if
                                                                      id =
                                                                      chosen
                                                                     then "on"
                                                                     else ""))|])
                                      [@ocaml.warning "-26-27"]))
                               }
                               [|(Melhole.View.Input __melhole_dispatch);(
                                 Melhole.View.Input chosen)|])));
                  ())
           })

With -hydratable, every template also gets the code that takes over a server's nodes in document order:

  $ cat > counter.ml <<'EOF_'
  > let view count = ((p ~children:[ Html.text "count: "; Html.int count; ((b ~children:[ Html.text "!" ] ()) [@JSX]) ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -hydratable -impl counter.ml
  let __melhole_template_1 =
    Melhole.View.hydratable (Melhole.Template.html "<p>count: <b>!</b></p>")
      {
        Js.Fn.I2 =
          (fun __melhole_scope __melhole_node ->
             let __melhole_node_0 = Melhole.Template.first __melhole_node in
             Melhole.View.text_at
               {
                 Melhole.Template.parent = __melhole_node;
                 before = (Melhole.Template.next_or_end __melhole_node_0)
               })
      }
      {
        Js.Fn.I3 =
          (fun __melhole_scope __melhole_node __melhole_collected ->
             ((let __melhole_from__melhole_hole_0 = __melhole_collected in
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
                __melhole_hole_0))
             [@ocaml.warning "-26-27"]))
      }
  let view count =
    Html.node
      (fun __melhole_dispatch ->
         Melhole.View.compiled __melhole_template_1 2
           {
             Js.Fn.I2 =
               (fun __melhole_scope __melhole_hole_0 ->
                  let __melhole_changed_0 =
                    Melhole.View.check __melhole_scope 0 count in
                  (match __melhole_changed_0 with
                   | Melhole.View.Unchanged -> ()
                   | _ ->
                       Melhole.View.put_text __melhole_scope 1 __melhole_hole_0
                         (string_of_int (count : int)));
                  ())
           })
  let __melhole_reads_view = Program.Reads { analysed = view; fields = (-1) }
