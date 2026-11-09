open Melhole
open Testing

external test_long : string -> (unit -> unit Js.Promise.t) -> int -> unit = "test"
external collect : unit -> unit = "gc" [@@mel.scope "globalThis"]

(** A JavaScript [WeakRef], to tell whether anything still holds what a list made. *)
type 'value weak

external weak : 'value -> 'value weak = "WeakRef" [@@mel.new]
external alive : 'value weak -> 'value Js.undefined = "deref" [@@mel.send]

(** What a law watches: a value of any type, held weakly. *)
type watched = Watched : 'value weak -> watched

(** What the handlers of the rows get from outside the row, a fresh object every time it changes. *)
type sent = { clicks : int ref }

(** One row, a fresh object for every run, so that whatever the loop keeps of it can be seen. *)
type item = { key : int; label : string }

(** What every row reads besides its item: [chosen] picks a row; [suffix] and [sent] are read by
    every row. *)
type outer = { chosen : int; suffix : string; sent : sent }

let marked outer item = match item.key = outer.chosen with true -> "on" | false -> ""
let site = View.loop_site ()
let row_template = Template.make ~html:"<li></li>" ~holes:[| Attr ([], "class"); Text ([], 0) |]
let clicked = View.event_key "click"
let made = ref []
let watch value = made := Watched (weak value) :: !made

let line_template =
  View.template (Template.html "<li></li>")
    (fun [@u] node ->
      let frame =
        ( Template.element node,
          View.attr_hole (Template.element node) "class",
          View.text_hole { parent = node; before = Template.first_or_end node } )
      in
      watch frame;
      frame)
    { placed = None; released = None; forgotten = None }

(** Which compiled loop a law runs on. *)
type loop = Each | Rows | Rows_selecting

let looped kind items outer =
  let inputs = [| View.Input outer.chosen; View.Input outer.suffix; View.Input outer.sent |] in
  let project =
   fun [@u] item _ out at ->
    Array.unsafe_set out at (View.Input (marked outer item));
    Array.unsafe_set out (at + 1) (View.Input outer.suffix);
    Array.unsafe_set out (at + 2) (View.Input outer.sent)
  in
  match kind with
  | Each ->
      View.each site View.Items items View.arrayed
        (fun [@u] item _ ->
          View.with_key (string_of_int item.key)
            (View.tpl_instance row_template [| HAttr (Some (marked outer item)); HText (item.label ^ outer.suffix) |]))
        project 3 inputs View.Unselecting
  | Rows | Rows_selecting ->
      View.rows items View.arrayed line_template
        (fun [@u] (root, _, _) -> root)
        (fun [@u] (root, marking, text) item ->
          View.set_attr marking (Some (marked outer item));
          View.set_text text (item.label ^ outer.suffix);
          View.put_handler root clicked (fun _ -> incr outer.sent.clicks))
        (fun [@u] item -> Reconcile.int_key item.key)
        project 3 inputs
        (match kind with
        | Rows_selecting ->
            View.Selecting
              (View.selection 6, [| View.selector View.Structural (Some outer.chosen) (fun [@u] item _ -> item.key) |])
        | Each | Rows -> View.Unselecting)

let edited tape pool (items, outer) =
  let count = Array.length items in
  match draw tape 7 with
  | 0 -> (Array.of_list (List.filter (fun _ -> draw tape 2 = 0) (Array.to_list pool)), outer)
  | 1 when count > 1 -> (Array.of_list (List.rev (Array.to_list items)), outer)
  | 2 when count > 0 ->
      let at = draw tape count in
      (Array.mapi (fun index item -> match index = at with true -> { item with label = item.label ^ "*" } | false -> item) items, outer)
  | 3 -> (items, { outer with chosen = draw tape (Array.length pool + 1) })
  | 4 -> (items, { outer with suffix = (match outer.suffix with "" -> "?" | _ -> "") })
  | 5 -> (items, { outer with sent = { clicks = ref 0 } })
  | _ -> (Array.sub pool 0 (draw tape (Array.length pool + 1)), outer)

let kept () =
  List.length (List.filter (fun (Watched held) -> Option.is_some (Js.Undefined.toOption (alive held))) !made)

let tick : unit -> unit Js.Promise.t =
  [%mel.raw {|function () { return new Promise((resolve) => setTimeout(resolve, 0)); }|}]

let settled () =
  let ( let* ) promise next = Js.Promise.then_ next promise in
  let rec rounds remaining =
    let* () = tick () in
    match remaining with
    | 0 -> Js.Promise.resolve ()
    | _ ->
        collect ();
        rounds (remaining - 1)
  in
  rounds 3

let shown root =
  Array.iter (fun node -> watch node) (nodes (child_nodes root))

let run kind values =
  let tape = tape values in
  made := [];
  let root = create_element document "ul" in
  let pool = Array.init (1 + draw tape 8) (fun key -> { key; label = "l" ^ string_of_int key }) in
  Array.iter watch pool;
  let start = (Array.sub pool 0 (draw tape (Array.length pool + 1)), { chosen = 0; suffix = ""; sent = { clicks = ref 0 } }) in
  watch (snd start).sent;
  let mounted = View.mount (looped kind (fst start) (snd start)) ~parent:root ~before:None in
  shown root;
  let rec step state remaining =
    match remaining with
    | 0 -> snd state
    | _ ->
        let ((items, outer) as next) = edited tape pool state in
        (match same outer.sent (snd state).sent with true -> () | false -> watch outer.sent);
        Array.iter watch items;
        View.patch mounted (looped kind items outer);
        shown root;
        step next (remaining - 1)
  in
  let last = step start (draw tape 12) in
  View.patch mounted (looped kind [||] last);
  (mounted, weak last.sent)

let kinds = [ ("View.each", Each); ("View.rows", Rows); ("View.rows with a selector", Rows_selecting) ]

let () =
  List.iter
    (fun (title, kind) ->
      describe ("Release laws: " ^ title) (fun () ->
          test_long
            "after any edits and a clear, nothing the list made is still reachable: no item, no row, no node, no handler, and nothing it was given but the last outer values; after unmount, not even those"
            (fun () ->
              check_async
                (async_property (tapes ~shortest:4 ~longest:40) (fun values ->
                     let mounted, last = run kind values in
                     let ( let* ) promise next = Js.Promise.then_ next promise in
                     let* () = settled () in
                     let cleared = kept () - Option.fold ~none:0 ~some:(fun _ -> 1) (Js.Undefined.toOption (alive last)) in
                     View.unmount mounted;
                     let* () = settled () in
                     expect (cleared, kept ()) |. to_equal (0, 0);
                     Js.Promise.resolve ()))
                [%mel.obj { numRuns = 40 }])
            60_000))
    kinds
