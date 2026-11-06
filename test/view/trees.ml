open Melhole
open Testing

let words = [| ""; "a"; "b"; "ab"; "<&>" |]
let labelled = Template.make ~html:"<div class=\"a\"><i></i></div>" ~holes:[| Attr ([], "title"); Text ([], 0); Child ([], 1) |]
let styled = Template.make ~html:"<span><b>x</b></span>" ~holes:[| Class_list []; Style []; Child ([], 0) |]
let scrolling = Template.make ~html:"<section></section>" ~holes:[| Handler ([], "scroll"); Child ([], 0) |]
let twin = Template.make ~html:"<section><!----></section>" ~holes:[| Child ([], 0); Child ([], 1) |]
let mixed = Template.make ~html:"<em>a<!---->b</em>" ~holes:[| Text ([], 1) |]
let row = Template.make ~html:"<li></li>" ~holes:[| Attr ([], "data-key"); Text ([], 0) |]
(** A word's row: its element, its text and the word written last. *)
type word = { root : Dom.element; text : Dom.text; mutable written : View.input }

let word_line =
  View.hydratable (Template.html "<b></b>")
    (fun [@u] node ->
      { root = Template.element node; text = View.text_at { parent = node; before = Template.first_or_end node }; written = View.unset })
    { placed = None; released = None; forgotten = None }
    (fun [@u] node collected ->
      let cursor = View.inside node in
      let text = View.adopt_text cursor (View.collected_text collected.text) in
      View.adopt_finish cursor;
      { root = Template.element node; text; written = View.unset })

let lazy_text n = View.text ("lazy" ^ string_of_int n)
let ignore_event (_ : Dom.event) = ()
let identities = [| ref 0; ref 1 |]

let rec description tape depth =
  match draw tape (if depth = 0 then 3 else 12) with
  | 0 -> View.text words.(draw tape 5)
  | 1 -> View.empty
  | 2 when depth = 0 -> View.tpl_instance mixed [| HText words.(draw tape 5) |]
  | 10 -> View.tpl_instance mixed [| HText words.(draw tape 5) |]
  | 11 ->
      let first = description tape (depth - 1) in
      let second = description tape (depth - 1) in
      View.tpl_instance twin [| HChild first; HChild second |]
  | 2 ->
      let count = draw tape 4 in
      View.list (List.init count (fun _ -> description tape (depth - 1)))
  | 3 ->
      let count = draw tape 5 in
      View.keyed
        (List.init count (fun _ ->
             let key = "k" ^ string_of_int (draw tape 4) in
             (key, description tape (depth - 1))))
  | 4 ->
      let title = match draw tape 3 with 0 -> None | n -> Some words.(n) in
      let text = words.(draw tape 5) in
      let child = description tape (depth - 1) in
      View.tpl_instance labelled [| HAttr title; HText text; HChild child |]
  | 5 ->
      let classes = List.filter (fun _ -> draw tape 2 = 1) [ "c1"; "c2"; "c3" ] in
      let style =
        List.filter (fun _ -> draw tape 2 = 1) [ ("color", "red"); ("width", "2px") ]
      in
      let child = description tape (depth - 1) in
      View.tpl_instance styled [| HClass classes; HStyle style; HChild child |]
  | 6 -> View.lazy1 lazy_text (draw tape 3)
  | 8 ->
      let items = Array.init (draw tape 5) (fun _ -> words.(draw tape 5)) in
      View.each View.Items items
        (fun [@u] item _ -> View.with_key item (View.text item))
        (fun [@u] _ _ _ _ -> ())
        0
        [||]
        View.Unselecting
  | 7 ->
      let items = Array.init (draw tape 5) (fun _ -> words.(draw tape 5)) in
      View.rows items word_line
        (fun [@u] word -> word.root)
        (fun [@u] word item ->
          View.put_text word.written word.text item;
          word.written <- View.Input item)
        (fun [@u] item -> item)
        (fun [@u] _ _ _ _ -> ())
        0
        [||]
        View.Unselecting
  | 9 ->
      let inner = description tape (depth - 1) in
      View.pure identities.(draw tape 2) [| View.Input words.(draw tape 5); View.Input inner |] (fun () -> inner)
  | _ ->
      let child = description tape (depth - 1) in
      View.tpl_instance scrolling [| HHandler ignore_event; HChild child |]

let decode values = description (tape values) 3


let rendered child =
  let root = create_element document "div" in
  let mounted = View.mount child ~parent:root ~before:None in
  let shown = without_empty_style (shapes (as_node root)) in
  View.unmount mounted;
  shown
