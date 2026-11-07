open Melhole

type phase = Bubble | Capture

(** Where React's event comes from. *)
type source =
  | Walked of string  (** A bubbling native event, delivered by melhole's walk. *)
  | Targeted of string  (** An event that reaches only its target, listened on the element. *)
  | Crossing of string  (** Enter or leave, made from the over and out events of this pointer kind. *)

type t = { source : source; phase : phase; shown : string  (** The synthetic event's [type]. *) }

let of_prop ~tag name =
  let target_only = function
    | "scroll" | "scrollend" | "load" | "error" | "abort" | "cancel" | "close" | "toggle" | "invalid" | "play" | "pause"
    | "playing" | "ended" | "canplay" | "canplaythrough" | "durationchange" | "emptied" | "encrypted" | "loadeddata"
    | "loadedmetadata" | "loadstart" | "progress" | "ratechange" | "seeked" | "seeking" | "stalled" | "suspend"
    | "timeupdate" | "volumechange" | "waiting" ->
        `Target
    | _ -> `Walked
  in
  let length = String.length name in
  match length > 2 && String.sub name 0 2 = "on" && Char.uppercase_ascii name.[2] = name.[2] with
  | false -> None
  | true ->
      let phase, base =
        match length > 9 && String.sub name (length - 7) 7 = "Capture" with
        | true -> (Capture, String.sub name 2 (length - 9))
        | false -> (Bubble, String.sub name 2 (length - 2))
      in
      let walked native shown = Some { source = Walked native; phase; shown } in
      match base with
      | "DoubleClick" -> walked "dblclick" "dblclick"
      | "Focus" -> walked "focusin" "focus"
      | "Blur" -> walked "focusout" "blur"
      | "Change" -> (
          match tag with "input" | "textarea" -> walked "onchange" "change" | _ -> walked "change" "change")
      | "MouseEnter" -> Some { source = Crossing "mouse"; phase; shown = "mouseenter" }
      | "MouseLeave" -> Some { source = Crossing "mouse"; phase; shown = "mouseleave" }
      | "PointerEnter" -> Some { source = Crossing "pointer"; phase; shown = "pointerenter" }
      | "PointerLeave" -> Some { source = Crossing "pointer"; phase; shown = "pointerleave" }
      | _ -> (
          let native = String.lowercase_ascii base in
          match target_only native with
          | `Target -> Some { source = Targeted native; phase; shown = native }
          | `Walked -> walked native native)

let enumerable : Raw.t -> string array =
  [%mel.raw {|function (value) { var names = []; for (var name in value) names.push(name); return names; }|}]

external stop_native : Dom.event -> unit = "stopPropagation" [@@mel.send]
external prevent_native : Dom.event -> unit = "preventDefault" [@@mel.send]
external related : Dom.event -> Dom.node Js.null = "relatedTarget" [@@mel.get]
external add_capture : Dom.document -> string -> (Dom.event -> unit) -> (_[@mel.as {json|true|json}]) -> unit
  = "addEventListener"
[@@mel.send]

(** Whether a synthetic event's propagation or default was stopped. *)
type stopped = Running | Stopped

let synthetic (native : Dom.event) shown =
  let event = Raw.make_object () in
  let propagation = ref Running and default = ref Running in
  Array.iter
    (fun name ->
      let value = Raw.get (Raw.of_any native) name in
      match Raw.view value with Callable _ -> () | _ -> Raw.set event name value)
    (enumerable (Raw.of_any native));
  (match (Raw.to_any (Raw.get (Raw.of_any native) "defaultPrevented") : bool) with
  | true -> default := Stopped
  | false -> ());
  Raw.set event "nativeEvent" native;
  Raw.set event "type" shown;
  Raw.set event "preventDefault" (fun () ->
      default := Stopped;
      Raw.set event "defaultPrevented" true;
      prevent_native native);
  Raw.set event "stopPropagation" (fun () ->
      propagation := Stopped;
      stop_native native);
  Raw.set event "isDefaultPrevented" (fun () -> match !default with Stopped -> true | Running -> false);
  Raw.set event "isPropagationStopped" (fun () -> match !propagation with Stopped -> true | Running -> false);
  Raw.set event "persist" (fun () -> ());
  Raw.set event "isPersistent" (fun () -> true);
  (event, propagation)

let kept native phase shown =
  let slot = match phase with Bubble -> "$$react:synthetic:" ^ shown | Capture -> "$$react:capturing:" ^ shown in
  match Raw.find (Raw.of_any native) slot with
  | Some found -> (found, fun () -> match (Raw.to_any (Raw.call0 (Raw.get found "isPropagationStopped")) : bool) with true -> Stopped | false -> Running)
  | None ->
      let event, propagation = synthetic native shown in
      Raw.set (Raw.of_any native) slot event;
      (event, fun () -> !propagation)

let slot_of phase shown = match phase with Bubble -> "$$react:on:" ^ shown | Capture -> "$$react:capture:" ^ shown
let portal_parent = "$$react:portal"

let logical_parent node =
  match Raw.find (Raw.of_any node) portal_parent with
  | Some parent -> Some (Raw.to_any parent : Dom.node)
  | None -> Dom_api.parent_node node

let call handler event node =
  Raw.set event "currentTarget" node;
  ignore (Raw.call1 handler event);
  Raw.set event "currentTarget" Raw.null

(** Whether a walk through a portal's ancestors is under way, so that the handlers it calls do not start another. *)
type bridging = Walking | Idle

let bridging = ref Idle
let dispatchers = ref []

let dispatcher native_type shown =
  match List.assoc_opt native_type !dispatchers with
  | Some found -> found
  | None ->
      let deliver (native : Dom.event) =
        let node = Dom_api.to_node (Dom_api.current_target native) in
        Option.iter
          (fun handler ->
            let event, _ = kept native Bubble shown in
            call handler event node)
          (Raw.find (Raw.of_any node) (slot_of Bubble shown))
      in
      dispatchers := (native_type, deliver) :: !dispatchers;
      deliver

let onwards key (native : Dom.event) (node : Dom.node) =
  match (Raw.find (Raw.of_any node) portal_parent, !bridging, Dom_api.cancel_bubble native) with
  | Some parent, Idle, false ->
      bridging := Walking;
      let rec up (at : Dom.node) =
        Option.iter
          (fun handle ->
            Dom_api.point_current_target native [%mel.obj { configurable = true; value = at }];
            handle native)
          (Dom_api.handler at key);
        match Dom_api.cancel_bubble native with true -> () | false -> Option.iter up (logical_parent at)
      in
      (match up (Raw.to_any parent) with
      | () -> bridging := Idle
      | exception error ->
          bridging := Idle;
          raise error);
      Dom_api.point_current_target native [%mel.obj { configurable = true; value = node }]
  | Some _, Walking, _ | Some _, _, true | None, _, _ -> ()

let capturing = ref []
let capture_names = ref []

let capture native_type =
  match List.mem native_type !capturing with
  | true -> ()
  | false ->
      capturing := native_type :: !capturing;
      let listened = match native_type with "onchange" -> [ "input"; "change" ] | other -> [ other ] in
      List.iter
        (fun listened ->
          add_capture Dom_api.document listened (fun native ->
              let rec path node found =
                match node with None -> found | Some node -> path (logical_parent node) (node :: found)
              in
              let nodes = path (Dom_api.target native) [] in
              let rec run nodes =
                match nodes with
                | [] -> ()
                | node :: rest -> (
                    let handlers =
                      List.filter_map
                        (fun (shown, _) -> Option.map (fun handler -> (shown, handler)) (Raw.find (Raw.of_any node) (slot_of Capture shown)))
                        (List.filter (fun (_, native) -> String.equal native native_type) !capture_names)
                    in
                    let stopped =
                      List.fold_left
                        (fun stopped (shown, handler) ->
                          match stopped with
                          | Stopped -> Stopped
                          | Running ->
                              let event, state = kept native Capture shown in
                              call handler event node;
                              state ())
                        Running handlers
                    in
                    match stopped with Stopped -> () | Running -> run rest)
              in
              run nodes))
        listened

let crossing_kinds = ref []

let crossing kind =
  match List.mem kind !crossing_kinds with
  | true -> ()
  | false ->
      crossing_kinds := kind :: !crossing_kinds;
      let enter = kind ^ "enter" and leave = kind ^ "leave" in
      let deliver native shown target other nodes =
        List.iter
          (fun node ->
            Option.iter
              (fun handler ->
                let event, _ = synthetic native shown in
                Raw.set event "target" target;
                Raw.set event "relatedTarget" other;
                call handler event node)
              (Raw.find (Raw.of_any node) (slot_of Bubble shown)))
          nodes
      in
      let rec ancestors node found =
        match node with None -> List.rev found | Some node -> ancestors (logical_parent node) (node :: found)
      in
      let crossed native from towards =
        let from_chain = ancestors from [] and to_chain = ancestors towards [] in
        let shared node = List.exists (fun other -> Dom_api.same other node) in
        let left = List.filter (fun node -> not (shared node to_chain)) from_chain in
        let entered = List.rev (List.filter (fun node -> not (shared node from_chain)) to_chain) in
        let raw node = Option.fold ~none:Raw.null ~some:Raw.of_any node in
        deliver native leave (raw from) (raw towards) left;
        deliver native enter (raw towards) (raw from) entered
      in
      Dom_api.add_document_listener Dom_api.document (kind ^ "out") (fun native ->
          crossed native (Dom_api.target native) (Js.Null.toOption (related native)));
      Dom_api.add_document_listener Dom_api.document (kind ^ "over") (fun native ->
          match Js.Null.toOption (related native) with
          | None -> crossed native None (Dom_api.target native)
          | Some _ -> ())

let targeted = "$$react:targeted:"

let put element prop handler =
  let node = Raw.of_any element in
  let slot = slot_of prop.phase prop.shown in
  Raw.set node slot (Option.fold ~none:Raw.undefined ~some:(fun handler -> handler) handler);
  match (prop.source, handler) with
  | _, None -> ()
  | Walked native, Some _ -> (
      match prop.phase with
      | Bubble ->
          Events.delegate native;
          Events.set element (Events.key_of native) (dispatcher native prop.shown)
      | Capture ->
          (match List.mem (prop.shown, native) !capture_names with
          | true -> ()
          | false -> capture_names := (prop.shown, native) :: !capture_names);
          capture native)
  | Targeted native, Some _ -> (
      match Raw.find node (targeted ^ native) with
      | Some _ -> ()
      | None ->
          Raw.set node (targeted ^ native) true;
          Dom_api.add_listener element native (fun native_event ->
              List.iter
                (fun phase ->
                  Option.iter
                    (fun handler ->
                      let event, _ = kept native_event phase prop.shown in
                      call handler event (Raw.of_any element))
                    (Raw.find node (slot_of phase prop.shown)))
                [ Capture; Bubble ]))
  | Crossing kind, Some _ -> crossing kind

external define : Dom.node -> string -> < get : unit -> 'handler ; set : 'handler -> unit ; configurable : bool > Js.t -> unit
  = "defineProperty"
[@@mel.scope "Object"]

let bridge node ~parent =
  let bridged =
    [
      ("click", "click"); ("dblclick", "dblclick"); ("mousedown", "mousedown"); ("mouseup", "mouseup");
      ("mousemove", "mousemove"); ("mouseover", "mouseover"); ("mouseout", "mouseout"); ("keydown", "keydown");
      ("keyup", "keyup"); ("keypress", "keypress"); ("focusin", "focus"); ("focusout", "blur"); ("input", "input");
      ("onchange", "change"); ("change", "change"); ("pointerdown", "pointerdown"); ("pointerup", "pointerup");
      ("pointermove", "pointermove"); ("pointerover", "pointerover"); ("pointerout", "pointerout");
      ("touchstart", "touchstart"); ("touchend", "touchend"); ("touchmove", "touchmove");
      ("contextmenu", "contextmenu"); ("submit", "submit"); ("wheel", "wheel");
    ]
  in
  let raw = Raw.of_any node in
  match (Raw.find raw portal_parent, Dom_api.node_type node) with
  | Some _, _ -> Raw.set raw portal_parent parent
  | None, 1 ->
      Raw.set raw portal_parent parent;
      List.iter
        (fun (native, _) ->
          let key = Events.key_of native in
          let own = ref (Raw.find raw key) in
          let combined (event : Dom.event) =
            Option.iter (fun handle -> ignore (Raw.call1 handle (Raw.of_any event))) !own;
            onwards key event node
          in
          define node key
            [%mel.obj { get = (fun () -> combined); set = (fun (handler : Dom.event -> unit) -> own := Raw.present (Raw.of_any handler)); configurable = true }])
        bridged
  | None, _ -> Raw.set raw portal_parent parent
