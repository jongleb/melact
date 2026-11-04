type child =
  | Text of string
  | Empty
  | List of child list
  | Keyed of (string * child) list
  | Instance of Template.t * hole array
  | Lazy of thunk

and hole =
  | HText of string
  | HAttr of string option
  | HProp : 'a -> hole
  | HClass of string list
  | HStyle of (string * string) list
  | HHandler of (Dom.event -> unit)
  | HRef of (Dom.element -> unit)
  | HChild of child

(** A render function with the arguments it is skipped for. *)
and thunk =
  | Lazy1 : ('a -> child) * 'a -> thunk
  | Lazy2 : ('a -> 'b -> child) * 'a * 'b -> thunk

(** A JS property value of any type. *)
type any = Any : 'a -> any [@@unboxed]

(** What a mounted description owns in the DOM. *)
type live =
  | Text_live of Dom.text * string
  | Empty_live
  | List_live of live array
  | Keyed_live of string array * live array
  | Instance_live of {
      template : Template.t;
      root : Dom.element;
      bindings : binding array;
    }
  | Lazy_live of thunk * live

(** A template hole bound to its DOM site, with the value last written. *)
and binding =
  | Attr_site of {
      element : Dom.element;
      name : string;
      mutable value : string option;
    }
  | Prop_site of { element : Dom.element; name : string; mutable value : any }
  | Text_site of { node : Dom.text; mutable value : string }
  | Child_site of {
      position : Template.position;
      mutable source : child;
      mutable live : live;
    }
  | Handler_site of Events.t
  | Ref_site of { element : Dom.element; mutable callback : Dom.element -> unit }
  | Style_site of {
      element : Dom.element;
      mutable value : (string * string) list;
    }
  | Class_site of { element : Dom.element; mutable value : string list }

type mounted = {
  position : Template.position;
  mutable source : child;
  mutable live : live;
}

let text value = Text value
let empty = Empty
let list children = List children
let keyed entries = Keyed entries
let tpl_instance template holes = Instance (template, holes)
let lazy1 render a = Lazy (Lazy1 (render, a))
let lazy2 render a b = Lazy (Lazy2 (render, a, b))

let force thunk =
  match thunk with Lazy1 (render, a) -> render a | Lazy2 (render, a, b) -> render a b

let insert (position : Template.position) node =
  Dom_api.insert_before position.parent node (Js.Null.fromOption position.before)

let restyle element old next =
  let style = Dom_api.style element in
  List.iter (fun (name, _) -> Dom_api.set_style style name "") old;
  List.iter (fun (name, value) -> Dom_api.set_style style name value) next

let reclass element old next =
  let classes = Dom_api.class_list element in
  List.iter (Dom_api.remove_class classes) old;
  List.iter (Dom_api.add_class classes) next

let rec each_node visit live =
  match live with
  | Text_live (node, _) -> visit (Dom_api.to_node node)
  | Empty_live -> ()
  | List_live items | Keyed_live (_, items) -> Array.iter (each_node visit) items
  | Instance_live instance -> visit (Dom_api.to_node instance.root)
  | Lazy_live (_, inner) -> each_node visit inner

let remove (position : Template.position) live =
  let rec release live =
    match live with
    | Text_live _ | Empty_live -> ()
    | List_live items | Keyed_live (_, items) -> Array.iter release items
    | Instance_live instance ->
        Array.iter
          (fun binding ->
            match binding with
            | Child_site site -> release site.live
            | Handler_site handler -> Events.release handler
            | Attr_site _ | Prop_site _ | Text_site _ | Ref_site _
            | Style_site _ | Class_site _ ->
                ())
          instance.bindings
    | Lazy_live (_, inner) -> release inner
  in
  each_node (Dom_api.remove_child position.parent) live;
  release live

let backwards count (position : Template.position) make =
  let rec front live after =
    match live with
    | Text_live (node, _) -> Some (Dom_api.to_node node)
    | Empty_live -> after
    | List_live items | Keyed_live (_, items) ->
        Array.fold_right front items after
    | Instance_live instance -> Some (Dom_api.to_node instance.root)
    | Lazy_live (_, inner) -> front inner after
  in
  let result = Array.make count Empty_live in
  let rec fill i before =
    if i >= 0 then (
      let live = make i { position with before } in
      result.(i) <- live;
      fill (i - 1) (front live before))
  in
  fill (count - 1) position.before;
  result

let rec build position child =
  match child with
  | Text value ->
      let node = Dom_api.create_text_node Dom_api.document value in
      insert position node;
      Text_live (node, value)
  | Empty -> Empty_live
  | List children -> List_live (Array.of_list (List.map (build position) children))
  | Keyed entries ->
      Keyed_live
        ( Array.of_list (List.map fst entries),
          Array.of_list (List.map (fun (_, child) -> build position child) entries)
        )
  | Instance (template, holes) ->
      let root, sites = Template.clone template in
      if Array.length sites <> Array.length holes then
        Js.Exn.raiseError
          (Printf.sprintf "Melact template expects %d hole values, got %d"
             (Array.length sites) (Array.length holes));
      let bindings = Array.map2 bind sites holes in
      insert position root;
      Array.iter
        (fun binding ->
          match binding with
          | Ref_site site -> site.callback site.element
          | Attr_site _ | Prop_site _ | Text_site _ | Child_site _
          | Handler_site _ | Style_site _ | Class_site _ ->
              ())
        bindings;
      Instance_live { template; root; bindings }
  | Lazy thunk -> Lazy_live (thunk, build position (force thunk))

and bind site hole =
  match (site, hole) with
  | Template.Attr (element, name), HAttr value ->
      Option.iter (Dom_api.set_attribute element name) value;
      Attr_site { element; name; value }
  | Prop (element, name), HProp value ->
      Dom_api.set_property element name value;
      Prop_site { element; name; value = Any value }
  | Text position, HText value ->
      let node = Dom_api.create_text_node Dom_api.document value in
      insert position node;
      Text_site { node; value }
  | Child position, HChild child ->
      Child_site { position; source = child; live = build position child }
  | Handler (element, event), HHandler handler ->
      Handler_site (Events.bind element event handler)
  | Ref element, HRef callback -> Ref_site { element; callback }
  | Style element, HStyle value ->
      restyle element [] value;
      Style_site { element; value }
  | Class_list element, HClass value ->
      reclass element [] value;
      Class_site { element; value }
  | ( ( Attr _ | Prop _ | Text _ | Child _ | Handler _ | Ref _ | Style _
      | Class_list _ ),
      _ ) ->
      Js.Exn.raiseError "Melact hole value does not match its template hole"

and update position live child =
  match (live, child) with
  | Text_live (node, value), Text next ->
      if Dom_api.same value next then live
      else (
        Dom_api.set_data node next;
        Text_live (node, next))
  | Empty_live, Empty -> live
  | List_live items, List children ->
      let children = Array.of_list children in
      let old_count = Array.length items in
      for i = Array.length children to old_count - 1 do
        remove position items.(i)
      done;
      List_live
        (backwards (Array.length children) position (fun i at ->
             if i < old_count then update at items.(i) children.(i)
             else build at children.(i)))
  | Keyed_live (keys, items), Keyed entries ->
      let next_keys = Array.of_list (List.map fst entries) in
      let children = Array.of_list (List.map snd entries) in
      let plan = Reconcile.plan ~old:keys ~next:next_keys in
      List.iter (fun i -> remove position items.(i)) plan.dropped;
      Keyed_live
        ( next_keys,
          backwards (Array.length children) position (fun j at ->
              match plan.steps.(j) with
              | Create -> build at children.(j)
              | Keep i -> update at items.(i) children.(j)
              | Move i ->
                  let live = update at items.(i) children.(j) in
                  each_node (insert at) live;
                  live) )
  | Instance_live instance, Instance (template, holes)
    when Dom_api.same instance.template template ->
      Array.iter2 rewrite instance.bindings holes;
      live
  | Lazy_live (old, inner), Lazy next -> (
      match (old, next) with
      | Lazy1 (f, a), Lazy1 (g, b) when Dom_api.same f g && Dom_api.same a b -> live
      | Lazy2 (f, a, b), Lazy2 (g, c, d)
        when Dom_api.same f g && Dom_api.same a c && Dom_api.same b d ->
          live
      | (Lazy1 _ | Lazy2 _), _ -> Lazy_live (next, update position inner (force next)))
  | (Text_live _ | Empty_live | List_live _ | Keyed_live _ | Instance_live _
    | Lazy_live _), _ ->
      let replacement = build position child in
      remove position live;
      replacement

and rewrite binding hole =
  match (binding, hole) with
  | Attr_site site, HAttr value ->
      if not (Option.equal Dom_api.same site.value value) then (
        (match value with
        | Some value -> Dom_api.set_attribute site.element site.name value
        | None -> Dom_api.remove_attribute site.element site.name);
        site.value <- value)
  | Prop_site site, HProp value ->
      let (Any old) = site.value in
      if not (Dom_api.same old value) then (
        Dom_api.set_property site.element site.name value;
        site.value <- Any value)
  | Text_site site, HText value ->
      if not (Dom_api.same site.value value) then (
        Dom_api.set_data site.node value;
        site.value <- value)
  | Child_site site, HChild child ->
      if not (Dom_api.same site.source child) then (
        site.live <- update site.position site.live child;
        site.source <- child)
  | Handler_site handler, HHandler next -> Events.set handler next
  | Ref_site site, HRef callback ->
      if not (Dom_api.same site.callback callback) then (
        site.callback <- callback;
        callback site.element)
  | Style_site site, HStyle value ->
      if
        not
          (List.equal
             (fun (name, value) (name', value') ->
               Dom_api.same name name' && Dom_api.same value value')
             site.value value)
      then (
        restyle site.element site.value value;
        site.value <- value)
  | Class_site site, HClass value ->
      if not (List.equal Dom_api.same site.value value) then (
        reclass site.element site.value value;
        site.value <- value)
  | ( ( Attr_site _ | Prop_site _ | Text_site _ | Child_site _ | Handler_site _
      | Ref_site _ | Style_site _ | Class_site _ ),
      _ ) ->
      Js.Exn.raiseError "Melact hole value does not match its template hole"

let mount child ~parent ~before =
  let position =
    { Template.parent = Dom_api.to_node parent; before = Option.map Dom_api.to_node before }
  in
  { position; source = child; live = build position child }

let patch mounted child =
  if not (Dom_api.same mounted.source child) then (
    mounted.live <- update mounted.position mounted.live child;
    mounted.source <- child)

let unmount mounted =
  remove mounted.position mounted.live;
  mounted.live <- Empty_live;
  mounted.source <- Empty
