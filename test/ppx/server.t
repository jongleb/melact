Under -server a component writes its HTML: hooks keyed from melact.server, the component rendered
when it is written, attributes in reason-react's order, an input's checked and value last, the
positions of a JSX list of children carried for useId, keys and handlers dropped:

  $ cat > page.ml <<'EOF_'
  > let[@react.component] make ~label ~items =
  >   let count, setCount = React.useState (fun () -> 0) in
  >   let id = React.useId () in
  >   ((div ~title:label ~className:"page" ~children:[
  >     ((input ~value:label ~checked:(count = 0) ~id ~onChange:(fun _ -> setCount (fun n -> n + 1)) ()) [@JSX]);
  >     React.string label; React.string "!";
  >     React.array (Array.map (fun item -> ((li ~key:item ~children:[ React.string item ] ()) [@JSX])) items)
  >   ] ()) [@JSX])
  > EOF_
  $ ./pp.exe -server -impl page.ml
  [@@@alert "-hook"]
  let () = React.reason_react_is_also_in_this_build_remove_it ()
  include
    struct
      type make_props =
        | Make_props of React.element [@@unboxed ]
      let __melhole_hook_1 =
        (Melact_server.Hook.key () : unit Melact_server.Hook.key)
      let __melhole_hook_2 =
        (Melact_server.Hook.key () : unit Melact_server.Hook.key)
      let makeProps ~label:(label as __melhole_prop_0)
        ~items:(items as __melhole_prop_1) ?key:(_ : string option) () =
        let __melhole_element =
          React.of_child
            (Melact_server.Component.render
               (fun () ->
                  React.to_child
                    (let (count, setCount) =
                       (React.useState
                          (Melact_server.Hook.unchecked __melhole_hook_1))
                         ((fun () -> 0)[@alert "+hook"]) in
                     let id =
                       (React.useId
                          (Melact_server.Hook.unchecked __melhole_hook_2)) () in
                     React.of_child
                       (Melhole_server.element
                          (fun __melhole_writer ->
                             ignore
                               (fun () __melhole_event ->
                                  ((fun _ ->
                                      setCount ((fun n -> n + 1)
                                        [@alert "+hook"]))[@alert "+hook"])
                                    (React.Event.ofNative __melhole_event));
                             Melhole_server.markup __melhole_writer
                               "<div class=\"page\"";
                             Melhole_server.attribute __melhole_writer "title"
                               (Some (label : string));
                             Melhole_server.markup __melhole_writer "><input";
                             Melhole_server.attribute __melhole_writer "id"
                               (Some (id : string));
                             Melhole_server.flag __melhole_writer "checked"
                               (count = 0 : bool);
                             Melhole_server.attribute __melhole_writer "value"
                               (Some (label : string));
                             Melhole_server.markup __melhole_writer "/>";
                             Melhole_server.dynamic_text __melhole_writer
                               (label : string);
                             Melhole_server.static_text __melhole_writer "!";
                             Melhole_server.forked __melhole_writer [|4;3|]
                               (React.to_child
                                  (React.array
                                     (Array.map
                                        ((fun item ->
                                            ignore (item : string);
                                            React.of_child
                                              (Melhole_server.element
                                                 (fun __melhole_writer ->
                                                    Melhole_server.markup
                                                      __melhole_writer "<li>";
                                                    Melhole_server.dynamic_text
                                                      __melhole_writer
                                                      (item : string);
                                                    Melhole_server.markup
                                                      __melhole_writer "</li>";
                                                    ())))[@alert "+hook"])
                                        items)));
                             Melhole_server.markup __melhole_writer "</div>";
                             ()))))) in
        Make_props __melhole_element
      external make : make_props -> React.element = "%identity"
    end
