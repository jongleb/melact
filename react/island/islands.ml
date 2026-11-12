open Melhole
open Melact_runtime

type foreign
type props

(** Any JavaScript value a props object holds. *)
type value

external value : 'a -> value = "%identity"
external as_props : value -> 'props Js.t = "%identity"
external nullable : value -> value Js.null = "%identity"
external field : value -> string -> value = "" [@@mel.get_index]
external set_field : value -> string -> value -> unit = "" [@@mel.set_index]
external keys : value -> string array = "keys" [@@mel.scope "Object"]
external fresh : unit -> value = "Object" [@@mel.new]
external same : value -> value -> bool = "is" [@@mel.scope "Object"]
external node_property : Dom.node -> string -> 'a Js.undefined = "" [@@mel.get_index]
external set_node_property : Dom.node -> string -> 'a -> unit = "" [@@mel.set_index]
external fragment : Dom.document -> Dom.node = "createDocumentFragment" [@@mel.send]
external append : Dom.node -> Dom.node -> unit = "appendChild" [@@mel.send]
external cancel_bubble : Dom.event -> bool = "cancelBubble" [@@mel.get]

let element_of : value -> value Js.undefined =
  [%mel.raw
    {|function (value) {
        return value !== null && typeof value === "object" && value.$$typeof === Symbol.for("react.element") ? value : undefined;
      }|}]

(** A JavaScript [WeakMap] from the functions an island was given to the ones it passes React. *)
type wrappers

external wrappers : unit -> wrappers = "WeakMap" [@@mel.new]
external wrapped : wrappers -> value -> value Js.undefined = "get" [@@mel.send]
external keep_wrapped : wrappers -> value -> value -> unit = "set" [@@mel.send]

let called : value -> value Js.undefined = [%mel.raw {|function (value) { return typeof value === "function" ? value : undefined; }|}]

let listed : value -> value array Js.undefined = [%mel.raw {|function (value) { return Array.isArray(value) ? value : undefined; }|}]

let content : value -> View.child Js.undefined =
  [%mel.raw
    {|function (value) {
        return value !== null && typeof value === "object" && typeof value.build === "function" && typeof value.patch === "function"
          ? value
          : undefined;
      }|}]

(** Whether a store's change is waiting for the next flush. *)
type state = Settled | Pending

(** A value React reads through [useSyncExternalStore], told only when it changes. *)
type 'value store = {
  mutable current : 'value;
  mutable listeners : (unit -> unit[@u]) list;
  mutable state : state;
  subscribe : Npm.subscribe;
  read : (unit -> 'value[@u]);
}

let pending : (unit -> unit) list ref = ref []

let store initial =
  let rec made =
    {
      current = initial;
      listeners = [];
      state = Settled;
      subscribe =
        (fun [@u] listener ->
          made.listeners <- listener :: made.listeners;
          fun [@u] () -> made.listeners <- List.filter (fun other -> not (other == listener)) made.listeners);
      read = (fun [@u] () -> made.current);
    }
  in
  made

let put store next =
  match store.current == next with
  | true -> ()
  | false -> (
      store.current <- next;
      match store.state with
      | Pending -> ()
      | Settled ->
          store.state <- Pending;
          pending :=
            (fun () ->
              store.state <- Settled;
              List.iter (fun listener -> listener () [@u]) store.listeners)
            :: !pending)

(** An island: a JavaScript component rendered by the shared root into [host], an element of Melact's. *)
type island = {
  id : string;
  host : Dom.element;
  component : foreign;
  shown : value store;  (** The props object React renders the island with. *)
  conversion : conversion;
  mutable placement : placement;
}

(** What turns the props Melact gives into those React renders with, kept from one render to the next. *)
and conversion = {
  owner : Dom.node;  (** Where the props' Melact content is in Melact's tree. *)
  writer : Instance.instance option;  (** The Melact instance that wrote the island. *)
  mutable slots : (string * held) list;  (** By the path of the prop that holds their content. *)
  wrappers : wrappers;  (** Functions in the props, each wrapped once so that its Melact results become React's. *)
}

(** Where an island renders in React's tree: found once Melact's commit has put its host in place. *)
and placement =
  | Unplaced
  | At_top  (** Among the islands of the shared root. *)
  | In_slot of slot  (** Among the islands of a slot, Melact content of another island. *)

(** Melact content where an island takes a React element: a [melact-slot] element React renders, which
    takes the content in when React connects it, and the islands nested in that content. *)
and slot = {
  key : string;
  holder : Dom.node;  (** A fragment the content waits in until React connects the slot. *)
  island_host : Dom.node;  (** The host of the island the slot belongs to: where the content is in Melact's tree. *)
  above : Instance.instance option;  (** The Melact instance that wrote the island: the content's parent. *)
  mutable element : Dom.element option;
  mutable wanted : View.child;  (** The content as Melact last gave it. *)
  mutable content : content;
  nested : island list store;
}

(** A slot's Melact content: built while React renders the slot, as React mounts only what a library renders. *)
and content = Unbuilt | Built of View.live

(** A slot with the React element that renders it, made once so that the island's props stay equal. *)
and held = { slot : slot; made : Npm.element }

let counter = ref 0

let next prefix =
  incr counter;
  prefix ^ string_of_int !counter

let slot_key = "$$melact_island:slot"

(** A JavaScript component and its props, as an island's mount carries them, so that another island can
    render them as a React element of its own tree. *)
type mounting = { foreign : foreign; given : value }

external mounting_field : View.child -> mounting Js.undefined = "$$melact_island:mounting" [@@mel.get]
external set_mounting : View.child -> mounting -> unit = "$$melact_island:mounting" [@@mel.set]

let mounting_of inner =
  Option.bind (Js.Undefined.toOption (content inner)) (fun child ->
      let key, inner = Option.fold ~none:(None, child) ~some:(fun (key, inner) -> (Some key, inner)) (View.entry child) in
      Option.map (fun mounting -> (key, mounting)) (Js.Undefined.toOption (mounting_field inner)))

let slots : (string, slot) Hashtbl.t = Hashtbl.create 16
let top = store []

let in_tree one other =
  let rec levels node inner =
    let rec up at =
      match Js.Undefined.toOption (node_property at slot_key) with
      | Some (slot : slot) -> Some (at, slot.island_host)
      | None -> Option.bind (Dom_api.parent_node at) up
    in
    Option.fold ~none:(node :: inner) ~some:(fun (element, host) -> levels host (element :: node :: inner)) (up node)
  in
  let in_react : Dom.node -> Dom.node -> int =
    [%mel.raw
      {|function (one, other) {
          const fiberOf = (node) => {
            for (const key in node) if (key.startsWith("__reactFiber$")) return node[key];
            return undefined;
          };
          const chain = (fiber) => {
            const up = [];
            for (; fiber; fiber = fiber.return) up.push(fiber);
            return up.reverse();
          };
          const same = (a, b) => a === b || a.alternate === b;
          const ones = chain(fiberOf(one)), others = chain(fiberOf(other));
          let at = 0;
          while (at < ones.length && at < others.length && same(ones[at], others[at])) at++;
          return at === 0 || at === ones.length || at === others.length ? 0 : ones[at].index - others[at].index;
        }|}]
  in
  let rec apart one other =
    let in_document a b = match Dom_api.compare_document_position a b land 4 with 0 -> 1 | _ -> -1 in
    match (one, other) with
    | a :: rest, b :: others when Dom_api.same a b -> apart rest others
    | a :: _, b :: _ -> (
        match (Js.Undefined.toOption (node_property a slot_key), Js.Undefined.toOption (node_property b slot_key)) with
        | Some (_ : slot), Some (_ : slot) -> ( match in_react a b with 0 -> in_document a b | order -> order)
        | Some _, None | None, Some _ | None, None -> in_document a b)
    | [], _ | _, [] -> 0
  in
  apart (levels one []) (levels other [])

(** Whether React is inside the flush that tells it of changed stores. *)
type flushing = Idle | Flushing

let flushing = ref Idle

(** Whether Melact content is being built while React renders a slot: an island built there goes at once
    among the slot's islands. *)
type building = Outside_react | Inside_react of slot

let building = ref Outside_react

let in_react slot work =
  let outer = !building in
  building := Inside_react slot;
  match work () with
  | result ->
      building := outer;
      result
  | exception error ->
      building := outer;
      raise error

let unplaced = ref []

let place_of_placement placement = match placement with In_slot slot -> Some slot.nested | At_top -> Some top | Unplaced -> None

let placed_in placement island =
  island.placement <- placement;
  Option.iter
    (fun place ->
      put place
        (List.stable_sort
           (fun one other -> in_tree (Dom_api.to_node one.host) (Dom_api.to_node other.host))
           (place.current @ [ island ])))
    (place_of_placement placement)

let flush () =
  let rec place_of node =
    match Js.Undefined.toOption (node_property node slot_key) with
    | Some slot -> In_slot slot
    | None -> Option.fold ~none:At_top ~some:place_of (Dom_api.parent_node node)
  in
  List.iter
    (fun island ->
      match island.placement with
      | At_top | In_slot _ -> ()
      | Unplaced -> placed_in (place_of (Dom_api.to_node island.host)) island)
    (List.rev !unplaced);
  unplaced := [];
  match (List.rev !pending, !flushing) with
  | [], _ -> ()
  | jobs, Flushing ->
      pending := [];
      List.iter (fun job -> job ()) jobs
  | jobs, Idle ->
      pending := [];
      flushing := Flushing;
      Instance.queue_captured
        (Instance.captured (fun () ->
             match Npm.flush_sync (fun [@u] () -> List.iter (fun job -> job ()) jobs) with
             | () -> flushing := Idle
             | exception error ->
                 flushing := Idle;
                 raise error))

(** Whether a flush is queued before the layout effects of the commit under way. *)
type request = Unrequested | Requested

let requested = ref Unrequested

let scheduled () =
  match !requested with
  | Requested -> ()
  | Unrequested ->
      requested := Requested;
      Instance.before_layout (fun () ->
          requested := Unrequested;
          flush ())

let defined =
  lazy
    (let define : (string -> (Dom.element -> unit[@u]) Js.undefined[@u]) -> unit =
        [%mel.raw
          {|function (find) {
              if (typeof customElements === "undefined" || customElements.get("melact-slot")) return;
              const fiberOf = (node) => {
                for (const key in node) if (key.startsWith("__reactFiber$")) return node[key];
                return undefined;
              };
              customElements.define("melact-slot", class extends HTMLElement {
                connectedCallback() {
                  const attach = find(this.getAttribute("data-slot"));
                  if (attach === undefined) return;
                  attach(this);
                  const parent = this.parentNode;
                  const mine = fiberOf(this);
                  const view = mine && mine.return;
                  if (!parent || !view) return;
                  const preceded = (host) => {
                    for (let at = host; at && at !== this; at = at.parentNode) if (at.previousSibling) return true;
                    return false;
                  };
                  for (let node = parent.firstChild; node && node !== this; node = node.nextSibling) {
                    let island;
                    for (let fiber = fiberOf(node); fiber; fiber = fiber.return) {
                      if (fiber.memoizedProps && fiber.memoizedProps.island) island = fiber.memoizedProps.island;
                      if (fiber === view || fiber.alternate === view) {
                        if (island && preceded(island.host)) parent.insertBefore(this, node);
                        return;
                      }
                    }
                  }
                }
              });
            }|}]
     in
     define (fun [@u] key ->
         Js.Undefined.fromOption
           (Option.map
              (fun slot ->
                fun [@u] element ->
                 slot.element <- Some element;
                 set_node_property (Dom_api.to_node element) slot_key slot;
                 match slot.content with
                 | Built live -> View.visit live (fun [@u] node -> append (Dom_api.to_node element) node)
                 | Unbuilt -> ())
              (Hashtbl.find_opt slots key))))

let handled given handler =
  List.iter
    (fun name -> set_field given name (value handler))
    [
      "onClick"; "onDoubleClick"; "onContextMenu"; "onAuxClick"; "onMouseDown"; "onMouseUp"; "onMouseMove"; "onMouseOver";
      "onMouseOut"; "onPointerDown"; "onPointerUp"; "onPointerMove"; "onPointerOver"; "onPointerOut"; "onPointerCancel";
      "onGotPointerCapture"; "onLostPointerCapture"; "onTouchStart"; "onTouchEnd"; "onTouchMove"; "onTouchCancel"; "onKeyDown";
      "onKeyUp"; "onKeyPress"; "onInput"; "onFocus"; "onBlur"; "onSubmit"; "onReset"; "onWheel"; "onCopy"; "onCut"; "onPaste";
      "onDrag"; "onDragStart"; "onDragEnd"; "onDragEnter"; "onDragLeave"; "onDragOver"; "onDrop"; "onAnimationStart";
      "onAnimationEnd"; "onAnimationIteration"; "onTransitionEnd";
    ]

let rooms = lazy (Dom_api.create_element Dom_api.document "div")

let island_view =
  Npm.memo (fun (props : < island : island > Js.t) ->
      let island = props##island in
      let given = fresh () in
      handled given (fun [@u] (synthetic : < nativeEvent : Dom.event ; stopPropagation : unit -> unit [@mel.meth] > Js.t) ->
          let native = synthetic##nativeEvent in
          Events.resume_at native (Dom_api.to_node island.host);
          match island.placement with
          | In_slot { element = Some element; _ } -> (
              Events.segment native (Dom_api.to_node element);
              match cancel_bubble native with true -> synthetic##stopPropagation () | false -> ())
          | In_slot { element = None; _ } | At_top | Unplaced -> ());
      set_field given "children"
        (value
           (Npm.create_portal
              (Npm.create_element (Npm.kind island.component)
                 (as_props (Npm.use_sync_external_store island.shown.subscribe island.shown.read)))
              island.host));
      Npm.create_portal (Npm.tag "melact-root" (as_props given)) (Lazy.force rooms))

let views islands =
  Npm.many (Array.of_list (List.map (fun island -> Npm.create_element island_view [%mel.obj { key = island.id; island }]) islands))

let position slot =
  { Template.parent = Option.fold ~none:slot.holder ~some:Dom_api.to_node slot.element; before = Js.null }

let shown_slot slot =
  (match slot.content with
  | Built _ -> ()
  | Unbuilt ->
      slot.content <- Built (in_react slot (fun () -> Instance.owning slot.above (fun () -> View.build slot.wanted (position slot)))));
  Npm.use_layout_effect
    (fun [@u] () ->
      (match !flushing with Idle -> Instance.settle () | Flushing -> ());
      fun [@u] () ->
        (match slot.content with Built live -> View.release live | Unbuilt -> ());
        slot.content <- Unbuilt;
        slot.element <- None;
        match !flushing with Idle -> Instance.settle () | Flushing -> ())
    [||];
  let given = fresh () in
  handled given (fun [@u] (synthetic : < nativeEvent : Dom.event ; currentTarget : Dom.node ; stopPropagation : unit -> unit [@mel.meth] > Js.t) ->
      let native = synthetic##nativeEvent in
      Events.segment native synthetic##currentTarget;
      match cancel_bubble native with true -> synthetic##stopPropagation () | false -> ());
  set_field given "data-slot" (value slot.key);
  set_field given "style" (value [%mel.obj { display = "contents" }]);
  set_field given "key" (value "slot");
  let nested = views (Npm.use_sync_external_store slot.nested.subscribe slot.nested.read) in
  Npm.many [| Npm.tag "melact-slot" (as_props given); nested |]

let slot_view = Npm.memo (fun (props : < slot : slot > Js.t) -> shown_slot props##slot)

let made_slot island_host above child =
  Lazy.force defined;
  let holder = fragment Dom_api.document in
  let key = next "s" in
  let slot =
    { key; holder; island_host; above; element = None; wanted = child; content = Unbuilt; nested = store [] }
  in
  set_node_property holder slot_key slot;
  Hashtbl.replace slots key slot;
  { slot; made = Npm.create_element slot_view [%mel.obj { key; slot }] }

let release_slot slot =
  Hashtbl.remove slots slot.key;
  match slot.content with Built live -> View.release live | Unbuilt -> ()

let refill slot child =
  slot.wanted <- child;
  match slot.content with Built live -> slot.content <- Built (View.update (position slot) live child) | Unbuilt -> ()

let render_slot_view =
  Npm.kind (fun (props : < child : View.child ; owner : Dom.node ; writer : Instance.instance option > Js.t) ->
      let kept = Npm.use_ref Js.Nullable.null in
      let slot =
        match Js.Nullable.toOption kept.current with
        | Some slot ->
            in_react slot (fun () -> refill slot props##child);
            slot
        | None ->
            let held = made_slot props##owner props##writer props##child in
            kept.current <- Js.Nullable.return held.slot;
            held.slot
      in
      Npm.use_layout_effect (fun [@u] () -> fun [@u] () -> release_slot slot) [||];
      shown_slot slot)

let rendering : value -> value -> value =
  [%mel.raw
    {|function (render, wrap) {
        return function () { return wrap(render.apply(this, arguments)); };
      }|}]

let release_all conversion =
  List.iter (fun (_, held) -> release_slot held.slot) conversion.slots;
  conversion.slots <- []

let rec converted conversion given previous =
  let kept = ref [] in
  let carried path inner =
    Option.map
      (fun child ->
        kept := path :: !kept;
        let held =
          match List.assoc_opt path conversion.slots with
          | Some held ->
              refill held.slot child;
              held
          | None ->
              let held = made_slot conversion.owner conversion.writer child in
              conversion.slots <- (path, held) :: conversion.slots;
              held
        in
        value held.made)
      (Js.Undefined.toOption (content inner))
  in
  let rec carry path inner before =
    match
      ( mounting_of inner,
        Js.Undefined.toOption (listed inner),
        Js.Undefined.toOption (element_of inner) )
    with
    | Some (key, mounting), _, _ ->
        let made = fresh () in
        set_field made "key" (value (Js.Null.fromOption key));
        set_field made "ref" (value Js.null);
        made_element (path ^ ".mount") (value mounting.foreign) mounting.given made before
    | None, Some entries, _ -> listing path entries before
    | None, None, Some made -> made_element (path ^ ".props") (field made "type") (field made "props") made before
    | None, None, None -> (
        let bound =
          Option.bind (Js.Undefined.toOption (content inner)) (fun child ->
              let parts = List.map value (View.items child) in
              match List.exists (fun part -> Option.is_some (mounting_of part)) parts with
              | true -> Some (Array.of_list parts)
              | false -> None)
        in
        match bound with
        | Some parts -> listing path parts before
        | None -> (
            match carried path inner with
            | Some slot -> (slot, match same slot before with true -> `Same | false -> `Changed)
            | None ->
                let shown = Option.fold ~none:inner ~some:wrapper (Js.Undefined.toOption (called inner)) in
                (shown, match same shown before with true -> `Same | false -> `Changed)))
  and listing path entries before =
    let earlier = Option.value ~default:[||] (Js.Undefined.toOption (listed before)) in
    let checked : value -> unit = [%mel.raw {|function (element) { if (element._store) element._store.validated = true; }|}] in
    let shown =
      Array.mapi
        (fun index entry ->
          let shown, change =
            carry (path ^ "." ^ string_of_int index) entry
              (match index < Array.length earlier with true -> earlier.(index) | false -> value Js.undefined)
          in
          Option.iter checked (Js.Undefined.toOption (element_of shown));
          (shown, change))
        entries
    in
    unchanged before (Array.length entries = Array.length earlier) shown (fun () -> value (Array.map fst shown))
  and made_element path kind props made before =
    let earlier = Js.Undefined.toOption (element_of before) in
    let shown, change =
      object_of path props (Option.fold ~none:(fresh ()) ~some:(fun earlier -> field earlier "props") earlier)
    in
    match (change, earlier) with
    | `Same, Some earlier when same (field earlier "type") kind && same (field earlier "key") (field made "key") -> (before, `Same)
    | (`Same | `Changed), (Some _ | None) ->
        let given = fresh () in
        Array.iter (fun name -> set_field given name (field shown name)) (keys shown);
        List.iter (fun name -> Option.iter (set_field given name) (Js.Null.toOption (nullable (field made name)))) [ "key"; "ref" ];
        (value (Npm.create_element (Npm.kind kind) (as_props given)), `Changed)
  and wrapper render =
    match Js.Undefined.toOption (wrapped conversion.wrappers render) with
    | Some made -> made
    | None ->
        let made =
          rendering render
            (value (fun result ->
                 match (mounting_of result, Js.Undefined.toOption (content result)) with
                 | Some (key, mounting), _ ->
                     value
                       (Npm.create_element (Npm.kind mounted_view)
                          [%mel.obj { key = Js.Null.fromOption key; mounting; owner = conversion.owner; writer = conversion.writer }])
                 | None, Some child ->
                     value
                       (Npm.create_element render_slot_view
                          [%mel.obj { child; owner = conversion.owner; writer = conversion.writer }])
                 | None, None -> result))
        in
        keep_wrapped conversion.wrappers render made;
        made
  and object_of path given previous =
    let names = keys given in
    let fields = Array.map (fun name -> (name, carry (path ^ "/" ^ name) (field given name) (field previous name))) names in
    let shown = Array.map snd fields in
    unchanged previous (Array.length names = Array.length (keys previous)) shown (fun () ->
        let made = fresh () in
        Array.iter (fun (name, (inner, _)) -> set_field made name inner) fields;
        made)
  and unchanged before same_length shown made =
    match (same_length, Array.for_all (fun (_, change) -> change = `Same) shown) with
    | true, true -> (before, `Same)
    | (true | false), (true | false) -> (made (), `Changed)
  in
  let shown, _ = object_of "" given previous in
  let gone, left = List.partition (fun (path, _) -> not (List.mem path !kept)) conversion.slots in
  conversion.slots <- left;
  List.iter (fun (_, held) -> release_slot held.slot) gone;
  shown

and mounted_view (props : < mounting : mounting ; owner : Dom.node ; writer : Instance.instance option > Js.t) =
  let kept = Npm.use_ref Js.Nullable.null in
  let conversion, previous =
    match Js.Nullable.toOption kept.current with
    | Some kept -> kept
    | None ->
        let made = ({ owner = props##owner; writer = props##writer; slots = []; wrappers = wrappers () }, ref (fresh ())) in
        kept.current <- Js.Nullable.return made;
        made
  in
  let mounting = props##mounting in
  let shown = converted conversion mounting.given !previous in
  previous := shown;
  Npm.use_layout_effect (fun [@u] () -> fun [@u] () -> release_all conversion) [||];
  Npm.create_element (Npm.kind mounting.foreign) (as_props shown)

let root =
  lazy
    (let container = Dom_api.create_element Dom_api.document "div" in
     let made = Npm.create_root container in
     Npm.flush_sync (fun [@u] () ->
         Npm.render made
           (Npm.create_element
              (Npm.memo (fun (_ : < > Js.t) -> views (Npm.use_sync_external_store top.subscribe top.read)))
              (Js.Obj.empty ())));
     made)

let hosting =
  View.hosting
    ~visit:(fun [@u] island see -> see (Dom_api.to_node island.host) [@u])
    ~first:(fun [@u] island _ -> Js.Null.return (Dom_api.to_node island.host))
    ~let_go:(fun [@u] island ->
      release_all island.conversion;
      (match place_of_placement island.placement with
      | Some place -> put place (List.filter (fun other -> not (other == island)) place.current)
      | None -> unplaced := List.filter (fun other -> not (other == island)) !unplaced);
      scheduled ())

let () =
  let earlier = !Instance.tree_order in
  Instance.tree_order :=
    Some
      (fun first second ->
        match (Instance.below first second, Instance.below second first) with
        | `Below, _ -> 1
        | _, `Below -> -1
        | `Apart, `Apart -> (
            match
              match (Instance.last_node first, Instance.last_node second) with
              | Some one, Some other -> in_tree one other
              | None, _ | _, None -> 0
            with
            | 0 -> Option.fold ~none:0 ~some:(fun order -> order first second) earlier
            | order -> order))

let mount foreign props =
  let given = value props in
  let made =
    View.host
      ~build:(fun [@u] position ->
        ignore (Lazy.force root);
        let host = Dom_api.create_element Dom_api.document "melact-island" in
        Dom_api.set_attribute host "style" "display: contents";
        View.insert position (Dom_api.to_node host);
        let island =
          {
            id = next "i";
            host;
            component = foreign;
            shown = store (fresh ());
            conversion = { owner = Dom_api.to_node host; writer = Instance.writer (); slots = []; wrappers = wrappers () };
            placement = Unplaced;
          }
        in
        put island.shown (converted island.conversion given island.shown.current);
        (match !building with
        | Inside_react slot -> placed_in (In_slot slot) island
        | Outside_react ->
            unplaced := island :: !unplaced;
            scheduled ());
        View.live hosting island)
      ~patch:(fun [@u] _ live ->
        match View.hosted hosting live with
        | Some island when island.component == foreign ->
            put island.shown (converted island.conversion given island.shown.current);
            scheduled ();
            Some live
        | Some _ | None -> None)
  in
  set_mounting made { foreign; given };
  made
