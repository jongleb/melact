open Testing

external head : Dom.document -> Dom.element = "head" [@@mel.get]
external set_inner_html : Dom.element -> string -> unit = "innerHTML" [@@mel.set]

(** A tag the model expects in the head: what dedupes it, and its precedence when it is a stylesheet. *)
type expected = { found_by : string; precedence : string option; shown : shape }

let () =
  describe "ReactDOM.Experimental resource hints" (fun () ->
    test "each hint adds its tag to the head once per resource, stylesheets grouped by precedence, as React 19 does" (fun () ->
      check
        (property (tapes ~shortest:1 ~longest:60) (fun values ->
             let tape = tape values in
             set_inner_html (head document) "";
             let hrefs = [| "/a"; "/b"; "/c"; "/d"; "/x\"y" |] in
             let model = ref [] in
             let add found_by ?precedence name attributes =
               match List.exists (fun entry -> String.equal entry.found_by found_by) !model with
               | true -> ()
               | false -> (
                   let entry = { found_by; precedence; shown = Element_shape (name, List.sort compare attributes, []) } in
                   let after predicate =
                     List.fold_left (fun (index, last) entry -> (index + 1, if predicate entry then Some index else last)) (0, None) !model
                     |> snd
                   in
                   let at =
                     match precedence with
                     | None -> None
                     | Some precedence -> (
                         match after (fun other -> other.precedence = Some precedence) with
                         | Some index -> Some index
                         | None -> after (fun other -> other.precedence <> None))
                   in
                   match at with
                   | None -> model := !model @ [ entry ]
                   | Some index -> model := List.concat (List.mapi (fun at other -> if at = index then [ other; entry ] else [ other ]) !model))
             in
             for _ = 1 to 1 + draw tape 12 do
               let href = hrefs.(draw tape 5) in
               match draw tape 11 with
               | 0 ->
                   ReactDOM.Experimental.preconnect href;
                   add ("preconnect " ^ href) "LINK" [ ("rel", "preconnect"); ("href", href) ]
               | 1 ->
                   ReactDOM.Experimental.prefetchDNS href;
                   add ("dns-prefetch " ^ href) "LINK" [ ("rel", "dns-prefetch"); ("href", href) ]
               | 2 ->
                   let kind, name = [| (`font, "font"); (`image, "image"); (`style, "style") |].(draw tape 3) in
                   ReactDOM.Experimental.preload href ~options:(ReactDOM.Experimental.preloadOptions ~_as:kind ()) ();
                   add ("preload " ^ href) "LINK" [ ("rel", "preload"); ("href", href); ("as", name) ]
               | 3 -> ReactDOM.Experimental.preload href ()
               | 4 ->
                   ReactDOM.Experimental.preloadModule href ();
                   add ("modulepreload " ^ href) "LINK" [ ("rel", "modulepreload"); ("href", href) ]
               | 5 ->
                   ReactDOM.Experimental.preinit href ~options:(ReactDOM.Experimental.preinitOptions ~_as:`script ()) ();
                   add ("script " ^ href) "SCRIPT" [ ("src", href); ("async", "") ]
               | 6 | 8 | 9 | 10 ->
                   let precedence, name = [| (Some `low, "low"); (Some `high, "high"); (None, "default") |].(draw tape 3) in
                   ReactDOM.Experimental.preinit href ~options:(ReactDOM.Experimental.preinitOptions ~_as:`style ?precedence ()) ();
                   add ("stylesheet " ^ href) ~precedence:name "LINK"
                     [ ("rel", "stylesheet"); ("href", href); ("data-precedence", name) ]
               | 7 | _ ->
                   ReactDOM.Experimental.preinitModule href ();
                   add ("script " ^ href) "SCRIPT" [ ("src", href); ("type", "module"); ("async", "") ]
             done;
             expect (shapes (as_node (head document))) |. to_equal (List.map (fun entry -> entry.shown) !model)))
        [%mel.obj { numRuns = 300 }]))

