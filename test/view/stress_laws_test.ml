open Melhole
open Testing

external test_long : string -> (unit -> unit) -> int -> unit = "test"
external first_element_child : Dom.element -> Dom.element Js.Nullable.t = "firstElementChild" [@@mel.get]

let line_template = Template.make ~html:"<li></li>" ~holes:[| Text ([], 0) |]
let box_template = Template.make ~html:"<div></div>" ~holes:[| Handler ([], "click"); Child ([], 0) |]
let site = View.loop_site ()
let line word = View.tpl_instance line_template [| HText word |]

(** How the children of one list are described. *)
type structure = Listed | Keyed | Each

let described structure words =
  match structure with
  | Listed -> View.list (List.map line words)
  | Keyed -> View.keyed (List.map (fun word -> (word, line word)) words)
  | Each ->
      View.each site View.Items (Array.of_list words) View.arrayed
        (fun [@u] word _ -> View.with_key word (line word))
        (fun [@u] _ _ _ _ -> ())
        0 [||] View.Unselecting

let html words = String.concat "" (List.map (fun word -> "<li>" ^ word ^ "</li>") words)

let edited tape words =
  let count = List.length words in
  match draw tape 4 with
  | 0 ->
      let ranked = List.map (fun word -> (draw tape 1_000_000, word)) words in
      List.map snd (List.stable_sort (fun (a, _) (b, _) -> compare a b) ranked)
  | 1 -> List.rev words
  | 2 ->
      let from = draw tape count and size = draw tape count in
      List.filteri (fun index _ -> index < from || index >= from + size) words
  | _ ->
      let at = draw tape (count + 1) and size = 1 + draw tape 5000 in
      let fresh = List.init size (fun index -> "n" ^ string_of_int (draw tape 1_000_000) ^ "-" ^ string_of_int index) in
      List.filteri (fun index _ -> index < at) words @ fresh @ List.filteri (fun index _ -> index >= at) words

let deduplicated words =
  let seen = Hashtbl.create (List.length words) in
  List.filter
    (fun word ->
      match Hashtbl.mem seen word with
      | true -> false
      | false ->
          Hashtbl.add seen word ();
          true)
    words

let rec nested depth leaf =
  match depth with
  | 0 -> View.text leaf
  | _ -> View.tpl_instance box_template [| HHandler (fun _ -> ()); HChild (nested (depth - 1) leaf) |]

external clearings : unit -> int = "__melhole_clearings"
[@@mel.scope "globalThis"]

let counted : unit =
  [%mel.raw
    {|(function () {
        if (!globalThis.__melhole_clearings) {
          var count = 0;
          var described = Object.getOwnPropertyDescriptor(Node.prototype, "textContent");
          Object.defineProperty(Node.prototype, "textContent", Object.assign({}, described, {
            set: function (value) { if (value === "") count++; described.set.call(this, value); }
          }));
          globalThis.__melhole_clearings = function () { return count; };
        }
      })()|}]

external query_all : Dom.element -> string -> Dom.nodeList = "querySelectorAll" [@@mel.send]
external element_of : Dom.node -> Dom.element = "%identity"

let small_edit tape words =
  let count = List.length words in
  match draw tape 5 with
  | 0 -> List.rev words
  | 1 ->
      let at = draw tape (count + 1) in
      List.filteri (fun index _ -> index < at) words @ [ "n" ^ string_of_int (draw tape 100000) ] @ List.filteri (fun index _ -> index >= at) words
  | 2 -> List.filteri (fun index _ -> index <> draw tape (count + 1)) words
  | 3 -> words @ List.init (1 + draw tape 5) (fun index -> "e" ^ string_of_int (draw tape 100000) ^ "-" ^ string_of_int index)
  | _ ->
      let ranked = List.map (fun word -> (draw tape 1000, word)) words in
      List.map snd (List.stable_sort (fun (a, _) (b, _) -> compare a b) ranked)

let () =
  describe "A chunked list" (fun () ->
      test "shows its rows in order, in groups of at most size that no two neighbours could share, and every row that stays keeps its node, in any group"
        (fun () ->
          check
            (property (tapes ~shortest:2 ~longest:40) (fun values ->
                 let tape = tape values in
                 let size = 1 + draw tape 7 in
                 let chunked words =
                   View.chunks ~size ~row_height:20 ~tag:"div"
                     (View.keyed (List.map (fun word -> (word, line word)) words))
                 in
                 let root = create_element document "section" in
                 let start = deduplicated (List.init (draw tape 30) (fun index -> "w" ^ string_of_int index)) in
                 let mounted = View.mount (chunked start) ~parent:root ~before:None in
                 let shape words =
                   let groups = Array.map element_of (nodes (query_all root "section > div")) in
                   let rows = Array.map (fun group -> Array.map element_of (nodes (query_all group "li"))) groups in
                   let counts = Array.map Array.length rows in
                   let rec settled index =
                     index + 1 >= Array.length counts
                     ||
                     let first = counts.(index) and second = counts.(index + 1) in
                     (first + second > size || 2 * min first second >= size) && settled (index + 1)
                   in
                   ( text_content root = String.concat "" words,
                     settled 0 && Array.length groups >= (List.length words + size - 1) / size,
                     Array.for_all (fun group -> Array.length group <= size && Array.length group > 0) rows,
                     rows )
                 in
                 let rec run remaining words before =
                   match remaining with
                   | 0 -> []
                   | _ ->
                       let next = deduplicated (small_edit tape words) in
                       View.patch mounted (chunked next);
                       let in_order, counted, bounded, rows = shape next in
                       let node_of rows_of word =
                         Array.find_map (fun group -> Array.find_opt (fun row -> String.equal (text_content row) word) group) rows_of
                       in
                       let kept =
                         List.for_all
                           (fun word ->
                             match List.mem word words with
                             | true -> Option.equal same (node_of before word) (node_of rows word)
                             | false -> true)
                           next
                       in
                       (in_order && counted && bounded && kept) :: run (remaining - 1) next rows
                 in
                 let _, _, _, first_rows = shape start in
                 let seen = run 6 start first_rows in
                 View.unmount mounted;
                 expect (List.for_all Fun.id seen, Js.String.length (inner_html root)) |. to_equal (true, 0)))
            [%mel.obj { numRuns = 300 }]));
  describe "Filling an empty place" (fun () ->
      test "a place that showed nothing takes its first content with no clearing write, in any form" (fun () ->
          check
            (property (tapes ~shortest:2 ~longest:8) (fun values ->
                 let tape = tape values in
                 counted;
                 let words = List.init (1 + draw tape 30) (fun index -> "w" ^ string_of_int index) in
                 let structure = match draw tape 3 with 0 -> Listed | 1 -> Keyed | _ -> Each in
                 let root = create_element document "ul" in
                 let mounted = View.mount (View.list []) ~parent:root ~before:None in
                 let before = clearings () in
                 View.patch mounted (described structure words);
                 let written = clearings () - before in
                 let shown = inner_html root in
                 View.unmount mounted;
                 expect (written, shown) |. to_equal (0, html words)))
            [%mel.obj { numRuns = 200 }]));
  describe "Wide and deep trees" (fun () ->
      List.iter
        (fun (title, structure) ->
          test_long ("a list of tens of thousands of rows, " ^ title ^ ", patches to what mounting shows after any edits")
            (fun () ->
              check
                (property (tapes ~shortest:4 ~longest:12) (fun values ->
                     let tape = tape values in
                     let start = List.init (20_000 + draw tape 20_000) (fun index -> "w" ^ string_of_int index) in
                     let root = create_element document "ul" in
                     let mounted = View.mount (described structure start) ~parent:root ~before:None in
                     let rec run remaining words =
                       match remaining with
                       | 0 -> []
                       | _ ->
                           let next = deduplicated (edited tape words) in
                           View.patch mounted (described structure next);
                           (String.equal (inner_html root) (html next)) :: run (remaining - 1) next
                     in
                     let seen = run 3 start in
                     View.unmount mounted;
                     expect seen |. to_equal [ true; true; true ]))
                [%mel.obj { numRuns = 3 }])
            120_000)
        [ ("unkeyed", Listed); ("keyed", Keyed); ("a compiled loop", Each) ];
      test_long "a tree up to a thousand levels deep mounts, patches its deepest text, bubbles a click and unmounts" (fun () ->
          check
            (property (tapes ~shortest:2 ~longest:6) (fun values ->
                 let tape = tape values in
                 let depth = 500 + draw tape 500 in
                 let root = attached () in
                 let mounted = View.mount (nested depth "first") ~parent:root ~before:None in
                 View.patch mounted (nested depth "second");
                 let deepest = select root "div" in
                 let rec down element remaining =
                   match remaining with
                   | 0 -> element
                   | _ -> down (Option.value ~default:element (Js.Nullable.toOption (first_element_child element))) (remaining - 1)
                 in
                 click (down deepest (depth - 1));
                 let text = text_content root in
                 View.unmount mounted;
                 expect text |. to_equal "second"))
            [%mel.obj { numRuns = 4 }])
        120_000)
