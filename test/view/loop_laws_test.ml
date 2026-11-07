open Melhole
open Testing

let each_site = View.loop_site ()

external remove_root : Dom.element -> unit = "remove" [@@mel.send]

(** One row of a keyed loop. The same objects recur between steps, so the loop can reuse rows. *)
type item = {
  key : string;
  label : string;
  group : string;  (** What a selector compares, shared by every third row. *)
  tag : string ref;  (** The same, as an object shared by every third row. *)
}

let groups = [| "a"; "b"; "c"; "d" |]
let tags = Array.map (fun group -> ref group) groups

(** What every row reads besides its item. *)
type outer = { chosen : string; suffix : string }

let fresh_items =
  Array.init 12 (fun index ->
      { key = "k" ^ string_of_int index; label = "l" ^ string_of_int index; group = groups.(index mod 3); tag = tags.(index mod 3) })
let relabelled =
  Array.mapi
    (fun index item -> { item with label = item.label ^ "*"; group = groups.((index + 1) mod 3); tag = tags.((index + 1) mod 3) })
    fresh_items

let outers =
  Array.concat
    (List.map
       (fun chosen -> [| { chosen; suffix = "" }; { chosen; suffix = "?" } |])
       [ "none"; "k0"; "k1"; "k2"; "k3" ])

let row_template = Template.make ~html:"<li></li>" ~holes:[| Attr ([], "class"); Text ([], 0) |]
let renders = ref 0
let marked outer item = match String.equal item.key outer.chosen with true -> "on" | false -> ""

let loop numbering items outer =
  View.each each_site numbering items Fun.id
    (fun [@u] item index ->
      incr renders;
      let place = match numbering with View.Items -> "" | View.Numbered -> string_of_int index ^ ":" in
      View.with_key item.key
        (View.tpl_instance row_template [| HAttr (Some (marked outer item)); HText (place ^ item.label ^ outer.suffix) |]))
    (fun [@u] item _ out at ->
      Array.unsafe_set out at (View.Input (marked outer item));
      Array.unsafe_set out (at + 1) (View.Input (item.label ^ outer.suffix)))
    2
    [| View.Input outer |]
    View.Unselecting

let line_template =
  View.template (Template.html "<li></li>")
    (fun [@u] node ->
      ( Template.element node,
        View.attr_hole (Template.element node) "class",
        View.text_hole { parent = node; before = Template.first_or_end node } ))
    { placed = None; released = None; forgotten = None }

let lines items outer =
  View.rows items Fun.id line_template
    (fun [@u] (root, _, _) -> root)
    (fun [@u] (_, marking, text) item ->
      incr renders;
      View.set_attr marking (Some (marked outer item));
      View.set_text text (item.label ^ outer.suffix))
    (fun [@u] item -> item.key)
    (fun [@u] item _ out at ->
      Array.unsafe_set out at (View.Input (marked outer item));
      Array.unsafe_set out (at + 1) (View.Input (item.label ^ outer.suffix)))
    2
    [| View.Input outer |]
    View.Unselecting

let shouted_site = View.loop_site ()

let shouted items outer =
  View.each shouted_site View.Items items Fun.id
    (fun [@u] item _ ->
      View.with_key item.key
        (View.tpl_instance row_template [| HAttr (Some (marked outer item)); HText (item.label ^ "!") |]))
    (fun [@u] item _ out at ->
      Array.unsafe_set out at (View.Input (marked outer item));
      Array.unsafe_set out (at + 1) (View.Input (item.label ^ "!")))
    2
    [| View.Input outer |]
    View.Unselecting

(** Which compiled loop a law runs on. *)
type loop = Each | Numbered_each | Rows

let looped kind items outer =
  match kind with
  | Each -> loop View.Items items outer
  | Numbered_each -> loop View.Numbered items outer
  | Rows -> lines items outer

let loops = [ ("View.each", Each); ("View.each, numbered rows", Numbered_each); ("View.rows", Rows) ]

(** How a step changes the rows. *)
type edit = Structural | Same_order

let step changed tape (items, outer) =
  let count = Array.length items in
  let pick () = draw tape (max 1 count) in
  let unused () =
    List.find_opt
      (fun item -> not (Array.exists (fun shown -> String.equal shown.key item.key) items))
      (List.filteri (fun index _ -> index >= draw tape 12) (Array.to_list fresh_items))
  in
  match (draw tape 10, count) with
  | 0, _ -> ((items, changed tape outer), Same_order)
  | 1, _ -> ((items, outer), Same_order)
  | 2, _ when count > 0 ->
      let at = pick () in
      let swap item = if String.equal item.key items.(at).key then relabelled.(int_of_string (String.sub item.key 1 (String.length item.key - 1))) else item in
      ((Array.map swap items, outer), Same_order)
  | 3, _ when count > 1 ->
      let next = Array.copy items in
      next.(0) <- items.(count - 1);
      next.(count - 1) <- items.(0);
      ((next, outer), Structural)
  | 4, _ when count > 0 ->
      let at = pick () in
      ((Array.of_list (List.filteri (fun index _ -> index <> at) (Array.to_list items)), outer), Structural)
  | 5, _ ->
      ( ( Option.fold ~none:items
            ~some:(fun item ->
              let at = draw tape (count + 1) in
              Array.concat [ Array.sub items 0 at; [| item |]; Array.sub items at (count - at) ])
            (unused ()),
          outer ),
        Structural )
  | 6, _ -> ((Array.of_list (List.rev (Array.to_list items)), outer), Structural)
  | 7, _ -> (([||], outer), Structural)
  | 8, _ when count > 1 ->
      let first = pick () and second = pick () in
      let next = Array.copy items in
      next.(first) <- items.(second);
      next.(second) <- items.(first);
      ((next, outer), Structural)
  | _, _ ->
      ( (Array.of_list (List.filter (fun _ -> draw tape 2 = 0) (Array.to_list fresh_items)), outer),
        Structural )

let other_outer tape _ = outers.(draw tape (Array.length outers))

let shown child =
  let root = create_element document "ul" in
  let mounted = View.mount child ~parent:root ~before:None in
  let shapes = shapes (as_node root) in
  View.unmount mounted;
  shapes

let start = (Array.sub fresh_items 0 6, outers.(0))

let watch_moves : unit -> unit -> int * int =
  [%mel.raw
    {|function () {
        var insert = Node.prototype.insertBefore, moving = false, moved = 0, reinserted = 0;
        Node.prototype.moveBefore = function (node, before) {
          moving = true; moved++;
          try { return insert.call(this, node, before); } finally { moving = false; }
        };
        Node.prototype.insertBefore = function (node, before) {
          if (!moving && node.parentNode === this) reinserted++;
          return insert.call(this, node, before);
        };
        return function () {
          delete Node.prototype.moveBefore;
          Node.prototype.insertBefore = insert;
          return [moved, reinserted];
        };
      }|}]

(** A pure component's identity and inputs, from small pools so that both recur. *)
type slot = { identity : int; input : string }

let identities = [| ref 0; ref 1 |]
let card_template = Template.make ~html:"<p></p>" ~holes:[| Text ([], 0) |]
let card_renders = ref 0

let cards slots =
  View.list
    (List.map
       (fun slot ->
         View.pure identities.(slot.identity)
           [| View.Input slot.input |]
           (fun () ->
             incr card_renders;
             View.tpl_instance card_template [| HText (string_of_int slot.identity ^ slot.input) |]))
       slots)

let inputs = [| "a"; "b"; "c" |]

let slots tape count =
  List.init count (fun _ -> { identity = draw tape 2; input = inputs.(draw tape 3) })

let () =
  List.iter (fun (title, kind) ->
  let loop = looped kind in
  describe ("Keyed loop laws: " ^ title) (fun () ->
      test "after any edits and outer changes, patching shows what mounting from scratch shows, beside any neighbours"
        (fun () ->
          check
            (property (tapes ~shortest:10 ~longest:80) (fun values ->
                 let tape = tape values in
                 let framed =
                   match draw tape 2 with
                   | 0 -> fun child -> child
                   | _ -> fun child -> View.list [ View.text "<"; child; View.text ">" ]
                 in
                 let root = create_element document "ul" in
                 let items, outer = start in
                 let mounted = View.mount (framed (loop items outer)) ~parent:root ~before:None in
                 let rec run state remaining =
                   match remaining with
                   | 0 -> []
                   | _ ->
                       let ((items, outer) as next), _ = step other_outer tape state in
                       View.patch mounted (framed (loop items outer));
                       (shapes (as_node root), shown (framed (loop items outer))) :: run next (remaining - 1)
                 in
                 let seen = run start (2 + draw tape 12) in
                 View.unmount mounted;
                 expect (List.map fst seen) |. to_equal (List.map snd seen)))
            [%mel.obj { numRuns = 400 }]);
      test "where the browser has moveBefore, every row that moves is moved with it, never inserted again" (fun () ->
          check
            (property (tapes ~shortest:10 ~longest:80) (fun values ->
                 let tape = tape values in
                 let root = attached () in
                 let items, outer = start in
                 let mounted = View.mount (loop items outer) ~parent:root ~before:None in
                 let stop = watch_moves () in
                 let rec run state remaining =
                   match remaining with
                   | 0 -> true
                   | _ ->
                       let ((items, outer) as next), _ = step other_outer tape state in
                       View.patch mounted (loop items outer);
                       shapes (as_node root) = shown (loop items outer) && run next (remaining - 1)
                 in
                 let agreed = run start (2 + draw tape 12) in
                 let _, reinserted = stop () in
                 View.unmount mounted;
                 remove_root root;
                 expect (agreed, reinserted) |. to_equal (true, 0)))
            [%mel.obj { numRuns = 300 }]);
      test "a row whose key stays keeps its element through any edits" (fun () ->
          check
            (property (tapes ~shortest:10 ~longest:80) (fun values ->
                 let tape = tape values in
                 let root = create_element document "ul" in
                 let items, outer = start in
                 let mounted = View.mount (loop items outer) ~parent:root ~before:None in
                 let elements () = nodes (child_nodes root) in
                 let rec run (items, outer) remaining =
                   match remaining with
                   | 0 -> []
                   | _ ->
                       let before = elements () in
                       let ((next_items, next_outer) as next), _ = step other_outer tape (items, outer) in
                       View.patch mounted (loop next_items next_outer);
                       let after = elements () in
                       let lost =
                         List.length
                           (List.filter
                              (fun (index, item) ->
                                Option.fold ~none:false
                                  ~some:(fun at -> not (same before.(index) after.(at)))
                                  (List.find_map
                                     (fun (at, other) -> match String.equal other.key item.key with true -> Some at | false -> None)
                                     (List.mapi (fun at other -> (at, other)) (Array.to_list next_items))))
                              (List.mapi (fun index item -> (index, item)) (Array.to_list items)))
                       in
                       lost :: run next (remaining - 1)
                 in
                 let seen = run start (2 + draw tape 12) in
                 View.unmount mounted;
                 expect (List.fold_left ( + ) 0 seen) |. to_be 0))
            [%mel.obj { numRuns = 300 }]);
      test "when the order is kept, exactly the rows whose item or projection changed are rendered" (fun () ->
          check
            (property (tapes ~shortest:10 ~longest:80) (fun values ->
                 let tape = tape values in
                 let root = create_element document "ul" in
                 let items, outer = start in
                 let mounted = View.mount (loop items outer) ~parent:root ~before:None in
                 let rec run ((items, outer) as state) remaining =
                   match remaining with
                   | 0 -> []
                   | _ -> (
                       let ((next_items, next_outer) as next), edit = step other_outer tape state in
                       renders := 0;
                       View.patch mounted (loop next_items next_outer);
                       match edit with
                       | Structural -> run next (remaining - 1)
                       | Same_order ->
                           let expected =
                             List.length
                               (List.filteri
                                  (fun index item ->
                                    let before = items.(index) in
                                    not
                                      (same before item
                                      && String.equal (marked outer before) (marked next_outer item)
                                      && String.equal (before.label ^ outer.suffix) (item.label ^ next_outer.suffix)))
                                  (Array.to_list next_items))
                           in
                           (!renders, expected) :: run next (remaining - 1))
                 in
                 let seen = run start (2 + draw tape 12) in
                 View.unmount mounted;
                 expect (List.map fst seen) |. to_equal (List.map snd seen)))
            [%mel.obj { numRuns = 400 }]);
      test "a change outside the rows that no projection sees writes nothing to the DOM" (fun () ->
          check
            (property (tapes ~shortest:4 ~longest:30) (fun values ->
                 let tape = tape values in
                 let root = create_element document "ul" in
                 let items = Array.sub fresh_items 0 (1 + draw tape 8) in
                 let outer = { chosen = "none"; suffix = "" } in
                 let mounted = View.mount (loop items outer) ~parent:root ~before:None in
                 let watcher = observer (fun () -> ()) in
                 observe watcher root
                   [%mel.obj { childList = true; subtree = true; attributes = true; characterData = true }];
                 View.patch mounted (loop items { chosen = "elsewhere"; suffix = "" });
                 let records = Array.length (take_records watcher) in
                 disconnect watcher;
                 View.unmount mounted;
                 expect records |. to_be 0))
            [%mel.obj { numRuns = 200 }])))
    loops;
  describe "Keyed loop laws: two loops in one hole" (fun () ->
      test "a hole that switches loops over the same items and outer shows what mounting the new loop shows" (fun () ->
          check
            (property (tapes ~shortest:4 ~longest:40) (fun values ->
                 let tape = tape values in
                 let root = create_element document "ul" in
                 let items, outer = start in
                 let pick () = match draw tape 2 with 0 -> loop View.Items items outer | _ -> shouted items outer in
                 let mounted = View.mount (pick ()) ~parent:root ~before:None in
                 let rec run remaining =
                   match remaining with
                   | 0 -> []
                   | _ ->
                       let next = pick () in
                       View.patch mounted next;
                       (shapes (as_node root), shown next) :: run (remaining - 1)
                 in
                 let seen = run (2 + draw tape 10) in
                 View.unmount mounted;
                 expect (List.map fst seen) |. to_equal (List.map snd seen)))
            [%mel.obj { numRuns = 200 }]));
  describe "Pure component laws" (fun () ->
      test "patching shows what mounting shows, and renders exactly the slots whose inputs or identity changed"
        (fun () ->
          check
            (property (tapes ~shortest:10 ~longest:60) (fun values ->
                 let tape = tape values in
                 let count = 1 + draw tape 4 in
                 let root = create_element document "div" in
                 let first = slots tape count in
                 let mounted = View.mount (cards first) ~parent:root ~before:None in
                 let rec run previous remaining =
                   match remaining with
                   | 0 -> []
                   | _ ->
                       let next = slots tape count in
                       let nodes_before = nodes (child_nodes root) in
                       card_renders := 0;
                       View.patch mounted (cards next);
                       let nodes_after = nodes (child_nodes root) in
                       let changed =
                         List.length
                           (List.filter
                              (fun (before, after) -> before.identity <> after.identity || not (String.equal before.input after.input))
                              (List.combine previous next))
                       in
                       let kept =
                         List.mapi (fun index (before, after) -> (before.identity = after.identity, same nodes_before.(index) nodes_after.(index)))
                           (List.combine previous next)
                       in
                       ((shapes (as_node root), !card_renders, List.map fst kept), (shown (cards next), changed, List.map snd kept))
                       :: run next (remaining - 1)
                 in
                 let seen = run first (1 + draw tape 10) in
                 View.unmount mounted;
                 expect (List.map fst seen) |. to_equal (List.map snd seen)))
            [%mel.obj { numRuns = 400 }]))

let hashed_template =
  View.template (Template.html "<li></li>")
    (fun [@u] node -> (Template.element node, View.text_hole { parent = node; before = Template.first_or_end node }))
    { placed = None; released = None; forgotten = None }

let hashed items =
  View.rows items Fun.id hashed_template
    (fun [@u] (root, _) -> root)
    (fun [@u] (_, text) item -> View.set_text text ("#" ^ item.label))
    (fun [@u] item -> item.key)
    (fun [@u] _ _ _ _ -> ())
    0 View.no_inputs View.Unselecting

let () =
  describe "Compiled loops of two templates" (fun () ->
      test "a hole that switches between two loops over the same rows shows what mounting the current one shows"
        (fun () ->
          check
            (property (tapes ~shortest:10 ~longest:80) (fun values ->
                 let tape = tape values in
                 let drawn (items, outer) = match draw tape 2 with 0 -> lines items outer | _ -> hashed items in
                 let root = create_element document "ul" in
                 let mounted = View.mount (drawn start) ~parent:root ~before:None in
                 let rec run state remaining =
                   match remaining with
                   | 0 -> []
                   | _ ->
                       let next, _ = step other_outer tape state in
                       let child = drawn next in
                       View.patch mounted child;
                       (shapes (as_node root), shown child) :: run next (remaining - 1)
                 in
                 let seen = run start (2 + draw tape 12) in
                 View.unmount mounted;
                 expect (List.map fst seen) |. to_equal (List.map snd seen)))
            [%mel.obj { numRuns = 400 }]))

let attached = Hashtbl.create 16

let attach =
  Array.map
    (fun item ->
      ( item.key,
        fun element ->
          Hashtbl.replace attached item.key
            (Option.value ~default:0 (Hashtbl.find_opt attached item.key)
            + match Js.Nullable.toOption element with Some _ -> 1 | None -> -1) ))
    fresh_items

let referring_template =
  View.template (Template.html "<li></li>")
    (fun [@u] node ->
      ( Template.element node,
        View.text_hole { parent = node; before = Template.first_or_end node },
        View.reference_hole (Template.element node) ))
    {
      placed = Some (fun [@u] (_, _, reference) -> View.place_reference reference);
      released = Some (fun [@u] (_, _, reference) -> View.release_reference reference);
      forgotten = None;
    }

let referring items =
  View.rows items Fun.id referring_template
    (fun [@u] (root, _, _) -> root)
    (fun [@u] (_, text, reference) item ->
      let callback = List.assoc item.key (Array.to_list attach) in
      View.set_text text item.label;
      View.set_reference reference callback callback)
    (fun [@u] item -> item.key)
    (fun [@u] _ _ _ _ -> ())
    0 View.no_inputs View.Unselecting

let () =
  describe "Compiled loops with refs" (fun () ->
      test "every row's ref holds its element while the row is shown, and lets go when it goes" (fun () ->
          check
            (property (tapes ~shortest:10 ~longest:80) (fun values ->
                 let tape = tape values in
                 Hashtbl.reset attached;
                 let held () =
                   List.filter (fun (_, count) -> count <> 0) (List.sort compare (List.of_seq (Hashtbl.to_seq attached)))
                 in
                 let expected items = List.sort compare (List.map (fun item -> (item.key, 1)) (Array.to_list items)) in
                 let root = create_element document "ul" in
                 let items, _ = start in
                 let mounted = View.mount (referring items) ~parent:root ~before:None in
                 let rec run state remaining =
                   match remaining with
                   | 0 -> []
                   | _ ->
                       let ((items, _) as next), _ = step other_outer tape state in
                       View.patch mounted (referring items);
                       (held (), expected items) :: run next (remaining - 1)
                 in
                 let seen = run start (2 + draw tape 12) in
                 View.unmount mounted;
                 expect ((held (), []) :: seen) |. to_equal (([], []) :: List.map (fun (_, wanted) -> (wanted, wanted)) seen)))
            [%mel.obj { numRuns = 300 }]))

(** What a row with a selector reads besides its item: the key the selection chooses, by its place
    in a pool that has one key no row has, and a suffix. *)
type picked = { choice : int option; suffix : string }

(** The key a selector compares. *)
type keying =
  | Group  (** A string, compared with [=]. *)
  | Boxed_group  (** A tuple made afresh by every call, compared with [=]. *)
  | Tag  (** An object shared by rows, compared with [==]. *)
  | Position  (** The row's index modulo 3, compared with [=]. *)

let class_of keying picked index item =
  match keying with
  | Group -> ( match Option.map (fun at -> groups.(at)) picked.choice with Some chosen when chosen = item.group -> "on" | _ -> "")
  | Boxed_group -> (
      match Option.map (fun at -> (groups.(at), 0)) picked.choice with
      | Some chosen when chosen = (item.group, 0) -> "on"
      | _ -> "")
  | Tag -> ( match Option.map (fun at -> tags.(at)) picked.choice with Some chosen when chosen == item.tag -> "on" | _ -> "")
  | Position -> ( match picked.choice with Some chosen when chosen = index mod 3 -> "on" | _ -> "")

let selector keying picked =
  match keying with
  | Group -> View.selector View.Structural (Option.map (fun at -> groups.(at)) picked.choice) (fun [@u] item _ -> item.group)
  | Boxed_group ->
      View.selector View.Structural (Option.map (fun at -> (groups.(at), 0)) picked.choice) (fun [@u] item _ -> (item.group, 0))
  | Tag -> View.selector View.Physical (Option.map (fun at -> tags.(at)) picked.choice) (fun [@u] item _ -> item.tag)
  | Position -> View.selector View.Structural picked.choice (fun [@u] _ index -> index mod 3)

let projected = ref 0
let each_selection = View.selection 2
let rows_selection = View.selection 2

let selected_project keying picked =
  fun [@u] item index out at ->
   incr projected;
   Array.unsafe_set out at (View.Input (class_of keying picked index item));
   Array.unsafe_set out (at + 1) (View.Input (item.label ^ picked.suffix))

let selected kind keying items picked =
  let inputs = [| View.Input picked.choice; View.Input picked.suffix |] in
  match kind with
  | Each | Numbered_each ->
      let numbering = match kind with Numbered_each -> View.Numbered | Each | Rows -> View.Items in
      View.each each_site numbering items Fun.id
        (fun [@u] item index ->
          incr renders;
          let place = match numbering with View.Items -> "" | View.Numbered -> string_of_int index ^ ":" in
          View.with_key item.key
            (View.tpl_instance row_template
               [| HAttr (Some (class_of keying picked index item)); HText (place ^ item.label ^ picked.suffix) |]))
        (selected_project keying picked) 2 inputs
        (View.Selecting (each_selection, [| selector keying picked |]))
  | Rows ->
      View.rows items Fun.id line_template
        (fun [@u] (root, _, _) -> root)
        (fun [@u] (_, marking, text) item ->
          incr renders;
          View.set_attr marking (Some (class_of keying picked 0 item));
          View.set_text text (item.label ^ picked.suffix))
        (fun [@u] item -> item.key)
        (selected_project keying picked) 2 inputs
        (View.Selecting (rows_selection, [| selector keying picked |]))

let repicked tape picked =
  let choice () = match draw tape 5 with 4 -> None | at -> Some at in
  match draw tape 4 with
  | 0 | 1 -> { picked with choice = choice () }
  | 2 -> { picked with suffix = (match picked.suffix with "" -> "?" | _ -> "") }
  | _ -> { choice = choice (); suffix = (match picked.suffix with "" -> "?" | _ -> "") }

let selections =
  [
    ("View.each", Each, Group);
    ("View.each", Each, Boxed_group);
    ("View.each", Each, Tag);
    ("View.each, numbered rows", Numbered_each, Group);
    ("View.each, numbered rows", Numbered_each, Boxed_group);
    ("View.each, numbered rows", Numbered_each, Tag);
    ("View.each, numbered rows", Numbered_each, Position);
    ("View.rows", Rows, Group);
    ("View.rows", Rows, Boxed_group);
    ("View.rows", Rows, Tag);
  ]

let keyed = function
  | Group -> "a string key"
  | Boxed_group -> "a tuple key made afresh"
  | Tag -> "a shared object compared with =="
  | Position -> "the index"

let () =
  List.iter
    (fun (title, kind, keying) ->
      let start = (Array.sub fresh_items 0 6, { choice = None; suffix = "" }) in
      let loop = selected kind keying in
      describe ("Selector laws: " ^ title ^ ", " ^ keyed keying) (fun () ->
          test "after any edits, selections and outer changes, patching shows what mounting from scratch shows" (fun () ->
              check
                (property (tapes ~shortest:10 ~longest:120) (fun values ->
                     let tape = tape values in
                     let framed =
                       match draw tape 2 with
                       | 0 -> fun child -> child
                       | _ -> fun child -> View.list [ View.text "<"; child; View.text ">" ]
                     in
                     let root = create_element document "ul" in
                     let items, picked = start in
                     let mounted = View.mount (framed (loop items picked)) ~parent:root ~before:None in
                     let rec run state remaining =
                       match remaining with
                       | 0 -> []
                       | _ ->
                           let ((items, picked) as next), _ = step repicked tape state in
                           View.patch mounted (framed (loop items picked));
                           (shapes (as_node root), shown (framed (loop items picked))) :: run next (remaining - 1)
                     in
                     let seen = run start (2 + draw tape 20) in
                     View.unmount mounted;
                     expect (List.map fst seen) |. to_equal (List.map snd seen)))
                [%mel.obj { numRuns = 300 }]);
          test "when the order is kept, exactly the rows whose item, selection or text changed are rendered" (fun () ->
              check
                (property (tapes ~shortest:10 ~longest:120) (fun values ->
                     let tape = tape values in
                     let root = create_element document "ul" in
                     let items, picked = start in
                     let mounted = View.mount (loop items picked) ~parent:root ~before:None in
                     let rec run ((items, picked) as state) remaining =
                       match remaining with
                       | 0 -> []
                       | _ -> (
                           let ((next_items, next_picked) as next), edit = step repicked tape state in
                           renders := 0;
                           View.patch mounted (loop next_items next_picked);
                           match edit with
                           | Structural -> run next (remaining - 1)
                           | Same_order ->
                               let expected =
                                 List.length
                                   (List.filteri
                                      (fun index item ->
                                        let before = items.(index) in
                                        not
                                          (same before item
                                          && String.equal (class_of keying picked index before)
                                               (class_of keying next_picked index item)
                                          && String.equal (before.label ^ picked.suffix) (item.label ^ next_picked.suffix)))
                                      (Array.to_list next_items))
                               in
                               (!renders, expected) :: run next (remaining - 1))
                     in
                     let seen = run start (2 + draw tape 20) in
                     View.unmount mounted;
                     expect (List.map fst seen) |. to_equal (List.map snd seen)))
                [%mel.obj { numRuns = 300 }]);
          match keying with
          | Boxed_group -> ()
          | Group | Tag | Position ->
              test "a change of the selection alone projects only the rows whose key was or is chosen" (fun () ->
                  check
                    (property (tapes ~shortest:10 ~longest:120) (fun values ->
                         let tape = tape values in
                         let root = create_element document "ul" in
                         let items, picked = start in
                         let mounted = View.mount (loop items picked) ~parent:root ~before:None in
                         let keyed_by chosen index item =
                           match (keying, chosen) with
                           | _, None -> 0
                           | (Group | Boxed_group), Some at -> ( match groups.(at) = item.group with true -> 1 | false -> 0)
                           | Tag, Some at -> ( match tags.(at) == item.tag with true -> 1 | false -> 0)
                           | Position, Some at -> ( match at = index mod 3 with true -> 1 | false -> 0)
                         in
                         let rec run ((items, picked) as state) remaining =
                           match remaining with
                           | 0 -> []
                           | _ ->
                               let ((next_items, next_picked) as next), _ = step repicked tape state in
                               projected := 0;
                               View.patch mounted (loop next_items next_picked);
                               let alone =
                                 Array.length items = Array.length next_items
                                 && List.for_all2 same (Array.to_list items) (Array.to_list next_items)
                                 && String.equal picked.suffix next_picked.suffix
                               in
                               let expected =
                                 match picked.choice = next_picked.choice with
                                 | true -> 0
                                 | false ->
                                     List.fold_left ( + ) 0
                                       (List.mapi
                                          (fun index item -> keyed_by picked.choice index item + keyed_by next_picked.choice index item)
                                          (Array.to_list next_items))
                               in
                               (match alone with true -> [ (!projected, expected) ] | false -> [])
                               @ run next (remaining - 1)
                         in
                         let seen = run start (2 + draw tape 20) in
                         View.unmount mounted;
                         expect (List.map fst seen) |. to_equal (List.map snd seen)))
                    [%mel.obj { numRuns = 300 }])))
    selections
