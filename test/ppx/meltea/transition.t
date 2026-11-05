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
             ((Melhole.View.attr_hole (Melhole.Template.element __melhole_node)
                 "class"),
               (Melhole.View.text_hole
                  {
                    Melhole.Template.parent = __melhole_node;
                    before = (Melhole.Template.first_or_end __melhole_node)
                  })))
      }
  let __melhole_template_2 =
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
                      Melhole.View.compiled __melhole_template_1 2
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
                                    Melhole.View.set_attr __melhole_hole_0
                                      (Some
                                         (if id = chosen then "on" else "" : 
                                         string)));
                               (match __melhole_changed_1 with
                                | Melhole.View.Unchanged -> ()
                                | _ ->
                                    Melhole.View.set_text __melhole_hole_1
                                      (string_of_int (id : int)));
                               ())
                        })) __melhole_dispatch)) in
    Html.node
      (fun __melhole_dispatch ->
         Melhole.View.compiled __melhole_template_2 4
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
                            (Melhole.View.each (Array.of_list rows)
                               {
                                 Js.Fn.I1 =
                                   (fun __melhole_item ->
                                      Html.render (row __melhole_item)
                                        __melhole_dispatch)
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
