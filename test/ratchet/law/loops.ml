open Melhole

type item = { key : string; label : string }

(** What every row reads besides its item. *)
type outer = { chosen : string; suffix : string }

let marked outer item = match String.equal item.key outer.chosen with true -> "on" | false -> ""
let listed items = Counters.seen Listed items

let projection outer =
 fun [@u] item _ out at ->
  Counters.bump Projected;
  Array.unsafe_set out at (View.Input (marked outer item));
  Array.unsafe_set out (at + 1) (View.Input (item.label ^ outer.suffix))

let each =
  let site = View.loop_site () in
  let row_template = Template.make ~html:"<li></li>" ~holes:[| Attr ([], "class"); Text ([], 0) |] in
  fun items outer ->
  View.each site View.Items items listed
    (fun [@u] item _ ->
      Counters.bump Refreshed;
      View.with_key (Counters.seen Keyed item.key)
        (View.tpl_instance row_template [| HAttr (Some (marked outer item)); HText (item.label ^ outer.suffix) |]))
    (projection outer) 2 [| View.Input outer |] View.Unselecting

let rows =
  let line_template =
    View.template (Template.html "<li></li>")
      (fun [@u] node ->
        ( Template.element node,
          View.attr_hole (Template.element node) "class",
          View.text_hole { parent = node; before = Template.first_or_end node } ))
      { placed = None; released = None; forgotten = None }
  in
  fun items outer ->
  View.rows items listed line_template
    (fun [@u] (root, _, _) -> root)
    (fun [@u] (_, marking, text) item ->
      Counters.bump Refreshed;
      View.set_attr marking (Some (marked outer item));
      View.set_text text (item.label ^ outer.suffix))
    (fun [@u] item -> Counters.seen Keyed item.key)
    (projection outer) 2 [| View.Input outer |] View.Unselecting

external remove_root : Dom.element -> unit = "remove" [@@mel.send]

let edited loop =
  let items = Array.init 100 (fun index -> { key = "k" ^ string_of_int index; label = "item " ^ string_of_int index }) in
  let fresh = Array.init 5 (fun index -> { key = "n" ^ string_of_int index; label = "new " ^ string_of_int index }) in
  let plain = { chosen = ""; suffix = "" } in
  let without at count items =
    Array.append (Array.sub items 0 at) (Array.sub items (at + count) (Array.length items - at - count))
  in
  let swapped first second items =
    let next = Array.copy items in
    next.(first) <- items.(second);
    next.(second) <- items.(first);
    next
  in
  let shorter = without 40 5 items in
  let longer = Array.concat [ Array.sub shorter 0 20; fresh; Array.sub shorter 20 (Array.length shorter - 20) ] in
  let adjacent = swapped 3 4 longer in
  let far = swapped 10 80 adjacent in
  let single = without 30 1 far in
  let renamed = Array.mapi (fun index item -> match index with 7 -> { item with label = item.label ^ "'" } | _ -> item) single in
  let reversed = Array.of_list (List.rev (Array.to_list renamed)) in
  let chosen = { plain with chosen = "k12" } in
  let first, rest =
  ( (items, plain),
  [
    (items, plain);
    (Array.copy items, plain);
    (shorter, plain);
    (longer, plain);
    (adjacent, plain);
    (far, plain);
    (single, plain);
    (single, chosen);
    (single, { chosen = "k13"; suffix = "" });
    (renamed, chosen);
    (reversed, chosen);
    (reversed, chosen);
  ] )
  in
  let root = Counters.unobserved Testing.attached in
  ignore (Counters.take ());
  let mounted = View.mount (loop (fst first) (snd first)) ~parent:root ~before:None in
  List.iter (fun (items, outer) -> View.patch mounted (loop items outer)) rest;
  View.unmount mounted;
  let counts = Counters.take () in
  Counters.unobserved (fun () -> remove_root root);
  counts

let scenarios = [| ("View.rows, keyed edits", fun () -> edited rows); ("View.each, keyed edits", fun () -> edited each) |]
