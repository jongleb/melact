Under -server a view writes its HTML: static markup merged into strings, separators decided at
compile time where the previous node is known, handlers kept only for typing:

  $ cat > page.ml <<'EOF_'
  > let view (count, label) =
  >   ((div ~className:"counter" ~children:[
  >     ((button ~onClick:Decrement ~children:[ Html.text "-" ] ()) [@JSX]);
  >     ((output ~className:(if count < 0 then "negative" else "") ~children:[ Html.int count ] ()) [@JSX]);
  >     Html.text "static"; Html.text label; Html.text "tail";
  >     ((input ~value:label ~checked:(count = 0) ~style:[ ("fontSize", "2px") ] ()) [@JSX]);
  >     ((textarea ~value:label ()) [@JSX]);
  >     Html.list (List.map (fun item -> ((li ~key:item ~children:[ Html.text item ] ()) [@JSX])) [ label ])
  >   ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -server -impl page.ml
  let view (count, label) =
    Html.node
      (fun __melhole_dispatch ->
         Melhole_server.element
           (fun __melhole_writer ->
              let __melhole_bound_0 = (label : string) in
              ignore (fun () __melhole_event -> __melhole_dispatch Decrement);
              Melhole_server.markup __melhole_writer
                "<div class=\"counter\"><button>-</button><output";
              Melhole_server.attribute __melhole_writer "class"
                (Some (if count < 0 then "negative" else "" : string));
              Melhole_server.markup __melhole_writer ">";
              Melhole_server.dynamic_text __melhole_writer
                (string_of_int (count : int));
              Melhole_server.markup_text __melhole_writer "</output>static";
              Melhole_server.dynamic_text __melhole_writer (label : string);
              Melhole_server.static_text __melhole_writer "tail";
              Melhole_server.markup __melhole_writer "<input";
              Melhole_server.style __melhole_writer
                ([("fontSize", "2px")] : (string * string) list);
              Melhole_server.flag __melhole_writer "checked" (count = 0 : bool);
              Melhole_server.attribute __melhole_writer "value"
                (Some (label : string));
              Melhole_server.markup __melhole_writer "/><textarea>";
              (Melhole_server.leading_newline __melhole_writer
                 __melhole_bound_0;
               Melhole_server.dynamic_text __melhole_writer __melhole_bound_0);
              Melhole_server.markup __melhole_writer "</textarea>";
              Melhole_server.write __melhole_writer
                (Html.render
                   (Html.list
                      (List.map
                         (fun item ->
                            ignore (item : string);
                            Html.node
                              (fun __melhole_dispatch ->
                                 Melhole_server.element
                                   (fun __melhole_writer ->
                                      Melhole_server.markup __melhole_writer
                                        "<li>";
                                      Melhole_server.dynamic_text
                                        __melhole_writer (item : string);
                                      Melhole_server.markup __melhole_writer
                                        "</li>";
                                      ()))) [label])) __melhole_dispatch);
              Melhole_server.markup __melhole_writer "</div>";
              ()))
