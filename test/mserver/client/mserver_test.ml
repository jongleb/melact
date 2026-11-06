open Testing

external melact_page : int array -> string = "page"
[@@mel.module "../../../../../server_js/output/test/mserver/server_js/rendered.mjs"]

external melact_markup : int array -> string = "markup"
[@@mel.module "../../../../../server_js/output/test/mserver/server_js/rendered.mjs"]

external melact_effects : unit -> int = "effects"
[@@mel.module "../../../../../server_js/output/test/mserver/server_js/rendered.mjs"]

external react_page : int array -> string = "page"
[@@mel.module "../../../../../react/output/test/mserver/react/rendered.mjs"]

external react_markup : int array -> string = "markup"
[@@mel.module "../../../../../react/output/test/mserver/react/rendered.mjs"]

external react_effects : unit -> int = "effects"
[@@mel.module "../../../../../react/output/test/mserver/react/rendered.mjs"]

external read_file : string -> string -> string = "readFileSync" [@@mel.module "node:fs"]
external parse_json : string -> 'a = "parse" [@@mel.scope "JSON"]
external set_inner_html : Dom.element -> string -> unit = "innerHTML" [@@mel.set]
external select_all : Dom.element -> string -> Dom.nodeList = "querySelectorAll" [@@mel.send]
external elements : Dom.nodeList -> Dom.element array = "from" [@@mel.scope "Array"]
external remove : Dom.element -> unit = "remove" [@@mel.send]
external value_of : Dom.element -> string = "value" [@@mel.get]
external checked_of : Dom.element -> bool = "checked" [@@mel.get]
external stringify : 'a -> string = "stringify" [@@mel.scope "JSON"]
external adopt : unit Js.Promise.t -> unit Js.Promise.t = "resolve" [@@mel.scope "Promise"]

external test_async_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"

let ( let* ) promise next = Js.Promise.then_ next promise
let act run = adopt (React.act run)
let corpus () = parse_json (read_file "_build/default/test/mserver/native/corpus.json" "utf8")

let rec ids shapes =
  List.concat_map
    (fun shape ->
      match shape with
      | Text_shape _ -> []
      | Element_shape (_, attributes, children) ->
          List.filter (fun (name, _) -> List.mem name [ "id"; "for" ]) attributes @ ids children)
    shapes

external css_text : Dom.element -> string = "cssText" [@@mel.get] [@@mel.scope "style"]
external clone : Dom.element -> (_[@mel.as {json|true|json}]) -> Dom.element = "cloneNode" [@@mel.send]
external set_attribute : Dom.element -> string -> string -> unit = "setAttribute" [@@mel.send]

let observe root =
  let rec normalized shapes =
    List.map
      (fun shape ->
        match shape with
        | Text_shape _ -> shape
        | Element_shape (tag, attributes, children) ->
            Element_shape
              ( tag,
                List.filter_map
                  (fun (name, value) ->
                    match (name, String.length value > 1 && value.[0] = ':') with
                    | ("checked" | "selected" | "value"), _ -> None
                    | _, true -> Some (name, ":id:")
                    | _, false -> Some (name, value))
                  attributes,
                normalized children ))
      shapes
  in
  let copy = clone root in
  Array.iter (fun element -> set_attribute element "style" (css_text element)) (elements (select_all copy "[style]"));
  ( normalized (shapes (as_node copy)),
    List.map
      (fun field -> (value_of field, checked_of field))
      (Array.to_list (elements (select_all root "input, textarea, select"))) )

let () =
  ([%mel.raw {|function () { console.error = function () {}; }|}] : unit -> unit) ();
  describe "Melact's server without a DOM" (fun () ->
      test "writes what React 18's renderToString (in production) and renderToStaticMarkup write, byte for byte" (fun () ->
          let production html =
            Js.String.replaceByRe ~regexp:[%re {|/<template data-msg="[^"]*"( data-stck="[^"]*")?><\/template>/g|}]
              ~replacement:"<template></template>" html
          in
          check
            (property (tapes ~shortest:0 ~longest:200) (fun values ->
                 expect (melact_page values, melact_markup values)
                 |. to_equal (production (react_page values), react_markup values)))
            [%mel.obj { numRuns = 2000 }]);
      test "runs no effect, as React's server runs none" (fun () ->
          ignore (melact_page [| 1; 1 |]);
          ignore (react_page [| 1; 1 |]);
          expect (melact_effects (), react_effects (), (corpus ())##effects) |. to_equal (0, 0, 0));
      test "writes natively what it writes under Melange, byte for byte" (fun () ->
          let pages = (corpus ())##pages in
          expect (Array.to_list (Array.map (fun entry -> (melact_page entry##tape, melact_markup entry##tape)) pages))
          |. to_equal (Array.to_list (Array.map (fun entry -> (entry##html, entry##markup)) pages)));
      test_async_long "is hydrated by Melact with the server's own elements and ids, after a hydration that failed too, and then patches like a mounted page"
        (fun () ->
          let hydrated = ref 0 in
          let* () =
          check_async
            (async_property (tapes ~shortest:0 ~longest:200) (fun values ->
                 match Pages.on_client (Pages.decode values) with
                 | `Sets_state | `Throws -> Js.Promise.resolve ()
                 | `Renders ->
                 incr hydrated;
                 let tape = tape values in
                 let broken = attached () in
                 set_inner_html broken "<main><div><i></i><b></b></div></main>";
                 let failed = ref None in
                 let* () = act (fun () -> failed := Some (ReactDOM.Client.hydrateRoot broken (Pages.shown [| 1; 0; 0; 2; 0; 3 |]))) in
                 let* () = act (fun () -> Option.iter (fun root -> ReactDOM.Client.unmount root ()) !failed) in
                 remove broken;
                 let served = attached () and fresh = attached () in
                 let html = melact_page values in
                 set_inner_html served html;
                 let sent = nodes (select_all served "*") in
                 let given = ids (shapes (as_node served)) in
                 let client = ref None in
                 let* () = act (fun () -> client := Some (ReactDOM.Client.hydrateRoot served (Pages.shown values))) in
                 let present = nodes (select_all served "*") in
                 let foreign =
                   Array.length (Js.Array.filter ~f:(fun node -> not (Array.exists (fun other -> same node other) sent)) present)
                   + Array.length (Js.Array.filter ~f:(fun node -> not (Array.exists (fun other -> same node other) present)) sent)
                 in
                 let kept = ids (shapes (as_node served)) in
                 let mounted = ReactDOM.Client.createRoot fresh in
                 let* () = act (fun () -> ReactDOM.Client.render mounted (Pages.shown values)) in
                 let first = (observe served, observe fresh) in
                 let next =
                   let drawn = Array.init (draw tape 60) (fun _ -> draw tape 1000) in
                   match Pages.on_client (Pages.decode drawn) with `Sets_state | `Throws -> [||] | `Renders -> drawn
                 in
                 let* () =
                   act (fun () ->
                       Option.iter (fun client -> ReactDOM.Client.render client (Pages.shown next)) !client;
                       ReactDOM.Client.render mounted (Pages.shown next))
                 in
                 let patched = (observe served, observe fresh) in
                 let* () =
                   act (fun () ->
                       Option.iter (fun client -> ReactDOM.Client.unmount client ()) !client;
                       ReactDOM.Client.unmount mounted ())
                 in
                 remove served;
                 remove fresh;
                 expect (stringify (foreign, kept, fst first, fst patched)) |. to_equal (stringify (0, given, snd first, snd patched));
                 Js.Promise.resolve ()))
            [%mel.obj { numRuns = 400 }]
          in
          expect (!hydrated > 200) |. to_be true;
          Js.Promise.resolve ())
        60000)
