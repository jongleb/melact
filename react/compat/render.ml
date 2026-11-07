open Melhole
open Melact_runtime

let behind = "_melact"

let context default =
  let made = Raw.record [ ("$$typeof", Element.Mark.context); ("_currentValue", default); ("_currentValue2", default) ] in
  Raw.set made behind (Context.make default);
  Raw.set made "Provider" (Raw.record [ ("$$typeof", Element.Mark.provider); ("_context", made) ]);
  Raw.set made "Consumer" made;
  made

let melact_context made : Raw.t Context.t = Raw.to_any (Raw.get made behind)
let read made = Instance.consume (Instance.current ()) (melact_context made)

let definitions : Component.t Raw.table = Raw.table ()

let definition kind =
  match Raw.lookup definitions kind with
  | Some found -> found
  | None ->
      let name =
        Option.fold ~none:"Anonymous" ~some:Raw.text_of
          (match Raw.find kind "displayName" with Some name -> Some name | None -> Raw.find kind "name")
      in
      let made = Component.make ~name in
      Raw.store definitions kind made;
      made

let melact value =
  match (Raw.view (Raw.get value "build"), Raw.view (Raw.get value "patch")) with
  | Callable _, Callable _ -> Some (Raw.to_any value : View.child)
  | _ -> None

(** What a class instance is to render next: what its state asked for, or everything. *)
type update = Requested | Forced

type instance = {
  self : Raw.t;  (** The object the class constructed. *)
  mutable queue : Raw.t list;  (** State updates not rendered yet, newest first. *)
  mutable callbacks : Raw.t list;  (** [setState] callbacks for the next commit, newest first. *)
  mutable update : update;
  mutable shown : View.child;
  mutable reference : Raw.t;
}

(** What a memo component rendered last, and for which props. *)
type memoized = { mutable given : Raw.t; mutable given_ref : Raw.t; mutable rendered : View.child }

let hook : unit Hook.key = Hook.key ()

(** A portal's children, mounted into its container. *)
type portaled = { container : Dom.element; mutable content : View.live }

let portals =
  View.hosting
    ~visit:(fun [@u] _ _ -> ())
    ~first:(fun [@u] _ after -> after)
    ~let_go:(fun [@u] placed ->
      View.visit placed.content (fun [@u] node -> Dom_api.remove_child (Dom_api.to_node placed.container) node);
      View.release placed.content)

let method_of self name = Option.map (fun method_ -> fun arguments -> Raw.call_on method_ self arguments) (Raw.find self name)

let merged_state state partial =
  Option.fold ~none:state ~some:(fun partial -> Raw.merged (Raw.make_object ()) state partial) (Raw.present partial)

let derived kind props state =
  Option.fold ~none:state
    ~some:(fun derive -> merged_state state (Raw.call2 derive props state))
    (Raw.find kind "getDerivedStateFromProps")

let class_context me kind =
  Option.fold ~none:(Raw.make_object ())
    ~some:(fun ancestor -> Instance.consume me (melact_context ancestor))
    (Raw.find kind "contextType")

let rec child value =
  match Raw.view value with
  | Missing | Flag _ | Callable _ | Other _ -> View.empty
  | Text text -> View.text text
  | Number _ -> View.text (Raw.text_of value)
  | Listed items -> listed items
  | Record record -> (
      let mark = Raw.get record "$$typeof" in
      match (Raw.same mark Element.Mark.element, Raw.same mark Element.Mark.portal) with
      | true, _ ->
          let made = typed (Element.kind record) (Element.props record) (Element.reference record) in
          Option.fold ~none:made ~some:(fun key -> View.with_key key made) (Element.key record)
      | false, true ->
          let made = portal (Raw.get record "children") (Raw.to_any (Raw.get record "containerInfo")) in
          Option.fold ~none:made ~some:(fun key -> View.with_key key made) (Option.map Raw.text_of (Raw.find record "key"))
      | false, false -> (
          match melact record with
          | Some inner -> inner
          | None -> Js.Exn.raiseError "Objects are not valid as a React child"))

and listed items =
  let used = ref [] in
  let entries =
    Array.to_list
      (Array.mapi
         (fun index item ->
           let wanted =
             match Option.bind (Element.of_value item) Element.key with
             | Some key -> "k" ^ key
             | None -> "i" ^ string_of_int index
           in
           let key = match List.mem wanted !used with true -> wanted ^ "#" ^ string_of_int index | false -> wanted in
           used := key :: !used;
           let made =
             match Element.of_value item with
             | Some element -> typed (Element.kind element) (Element.props element) (Element.reference element)
             | None -> child item
           in
           (key, made))
         items)
  in
  View.keyed entries

and typed kind props reference =
  match Raw.view kind with
  | Text tag ->
      let children =
        match Raw.find props "dangerouslySetInnerHTML" with Some _ -> View.empty | None -> child (Raw.get props "children")
      in
      Host.child tag props reference children
  | Callable component -> (
      match Option.bind (Raw.find component "prototype") (fun prototype -> Raw.find prototype "isReactComponent") with
      | Some _ -> classy component props reference
      | None ->
          Instance.component (definition component) [| View.Input props |] (fun () -> child (Raw.call1 component props)))
  | Other symbol
    when Raw.same symbol Element.Mark.fragment || Raw.same symbol Element.Mark.strict_mode
         || Raw.same symbol Element.Mark.profiler || Raw.same symbol Element.Mark.suspense ->
      child (Raw.get props "children")
  | Record special -> (
      let mark = Raw.get special "$$typeof" in
      let is known = Raw.same mark known in
      match () with
      | () when is Element.Mark.forward_ref ->
          let render = Raw.get special "render" in
          Instance.component (definition special) [| View.Input props; View.Input reference |] (fun () ->
              child (Raw.call2 render props reference))
      | () when is Element.Mark.memo ->
          let inner = Raw.get special "type" in
          let same_props =
            match Raw.find special "compare" with
            | Some compare -> fun before after -> (match (Raw.to_any (Raw.call2 compare before after) : bool) with true -> View.Unchanged | false -> View.Changed)
            | None -> Raw.shallow
          in
          Instance.component (definition special) [| View.Input props; View.Input reference |] (fun () ->
              let me = Instance.current () in
              match Instance.found me (Hook.unchecked hook) with
              | Some (kept : memoized) -> (
                  match (same_props kept.given props, Raw.same kept.given_ref reference) with
                  | View.Unchanged, true -> kept.rendered
                  | (View.Unchanged | View.Changed), _ ->
                      kept.given <- props;
                      kept.given_ref <- reference;
                      kept.rendered <- typed inner props reference;
                      kept.rendered)
              | None ->
                  let rendered = typed inner props reference in
                  Instance.put me (Hook.unchecked hook) { given = props; given_ref = reference; rendered };
                  rendered)
      | () when is Element.Mark.provider ->
          Instance.provide (melact_context (Raw.get special "_context")) (Raw.get props "value") (child (Raw.get props "children"))
      | () when is Element.Mark.context ->
          Instance.component (definition special) [| View.Input props |] (fun () ->
              child (Raw.call1 (Raw.get props "children") (read special)))
      | () -> Js.Exn.raiseError "melact: this kind of React element is not supported (React.lazy)")
  | Missing | Flag _ | Number _ | Listed _ | Other _ ->
      Js.Exn.raiseError "Element type is invalid: expected a string or a class/function"

and classy kind props reference =
  Instance.component (definition kind) [| View.Input props; View.Input reference |] (fun () ->
      let me = Instance.current () in
      match Instance.found me (Hook.unchecked hook) with
      | Some (instance : instance) -> updated me instance kind props reference
      | None ->
          let instance = mounted me kind props reference in
          Instance.put me (Hook.unchecked hook) instance;
          instance.shown)

and render_of self = child (Raw.call_on (Raw.get self "render") self [||])

and committed me instance work =
  let callbacks = List.rev instance.callbacks in
  instance.callbacks <- [];
  Instance.after_commit me Instance.Layout Instance.Run (fun () ->
      work ();
      List.iter (fun callback -> ignore (Raw.call_on callback instance.self [||])) callbacks)

and mounted me kind props reference =
  let context = class_context me kind in
  let self = Raw.construct kind [| props; context |] in
  Raw.set self "props" props;
  Raw.set self "context" context;
  (match Raw.present (Raw.get self "state") with Some _ -> () | None -> Raw.set self "state" Raw.null);
  let instance = { self; queue = []; callbacks = []; update = Requested; shown = View.empty; reference } in
  let enqueue payload callback =
    instance.queue <- payload :: instance.queue;
    Option.iter (fun callback -> instance.callbacks <- callback :: instance.callbacks) (Raw.present callback);
    Instance.invalidate me
  in
  Raw.set self "updater"
    (Raw.record
       [
         ("isMounted", Raw.of_any (fun _ -> true));
         ("enqueueSetState", Raw.of_any (fun _ payload callback -> enqueue payload callback));
         ("enqueueReplaceState", Raw.of_any (fun _ payload callback -> enqueue payload callback));
         ( "enqueueForceUpdate",
           Raw.of_any (fun _ callback ->
               instance.update <- Forced;
               Option.iter (fun callback -> instance.callbacks <- callback :: instance.callbacks) (Raw.present callback);
               Instance.invalidate me) );
       ]);
  Raw.set self "state" (derived kind props (Raw.get self "state"));
  instance.shown <- render_of self;
  committed me instance (fun () ->
      Option.iter (fun did -> ignore (did [||])) (method_of self "componentDidMount");
      Option.iter (fun reference -> Host.assign reference self) (Raw.present reference));
  Instance.on_unmount me (fun () ->
      Option.iter (fun will -> ignore (will [||])) (method_of self "componentWillUnmount");
      Option.iter (fun reference -> Host.assign reference Raw.null) (Raw.present instance.reference));
  instance

and updated me instance kind props reference =
  let self = instance.self in
  let previous_props = Raw.get self "props" and previous_state = Raw.get self "state" in
  let context = class_context me kind in
  let state =
    List.fold_left
      (fun state payload ->
        match Raw.view payload with
        | Callable update -> merged_state state (Raw.call_on update self [| state; props |])
        | _ -> merged_state state payload)
      previous_state (List.rev instance.queue)
  in
  instance.queue <- [];
  let state = derived kind props state in
  let wanted =
    match instance.update with
    | Forced -> `Render
    | Requested -> (
        match method_of self "shouldComponentUpdate" with
        | Some should -> (match (Raw.to_any (should [| props; state; context |]) : bool) with true -> `Render | false -> `Skip)
        | None -> (
            match Option.bind (Raw.find kind "prototype") (fun prototype -> Raw.find prototype "isPureReactComponent") with
            | Some _ -> (
                match (Raw.shallow previous_props props, Raw.shallow previous_state state) with
                | View.Unchanged, View.Unchanged -> `Skip
                | _ -> `Render)
            | None -> `Render))
  in
  instance.update <- Requested;
  Raw.set self "props" props;
  Raw.set self "state" state;
  Raw.set self "context" context;
  (match Raw.same instance.reference reference with
  | true -> ()
  | false ->
      Option.iter (fun old -> Host.assign old Raw.null) (Raw.present instance.reference);
      instance.reference <- reference;
      Instance.after_commit me Instance.Layout Instance.Run (fun () ->
          Option.iter (fun reference -> Host.assign reference self) (Raw.present reference)));
  match wanted with
  | `Skip ->
      committed me instance ignore;
      instance.shown
  | `Render ->
      let shown = render_of self in
      let snapshot =
        Option.fold ~none:Raw.undefined
          ~some:(fun snapshot -> snapshot [| previous_props; previous_state |])
          (method_of self "getSnapshotBeforeUpdate")
      in
      instance.shown <- shown;
      committed me instance (fun () ->
          Option.iter (fun did -> ignore (did [| previous_props; previous_state; snapshot |])) (method_of self "componentDidUpdate"));
      shown

and portal content container =
  let inside = { Template.parent = Dom_api.to_node container; before = Js.null } in
  let bridged live parent = View.visit live (fun [@u] node -> Synthetic.bridge node ~parent) in
  View.host
    ~build:(fun [@u] (position : Template.position) ->
      let live = View.build (child content) inside in
      bridged live position.parent;
      View.live portals { container; content = live })
    ~patch:(fun [@u] (position : Template.position) live ->
      match View.hosted portals live with
      | Some placed when Dom_api.same placed.container container ->
          placed.content <- View.update inside placed.content (child content);
          bridged placed.content position.parent;
          Some live
      | Some _ | None -> None)
