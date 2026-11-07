module Mark = struct
  let element = Raw.symbol "react.element"
  let portal = Raw.symbol "react.portal"
  let fragment = Raw.symbol "react.fragment"
  let strict_mode = Raw.symbol "react.strict_mode"
  let profiler = Raw.symbol "react.profiler"
  let suspense = Raw.symbol "react.suspense"
  let provider = Raw.symbol "react.provider"
  let context = Raw.symbol "react.context"
  let forward_ref = Raw.symbol "react.forward_ref"
  let memo = Raw.symbol "react.memo"
  let lazy_ = Raw.symbol "react.lazy"
end

let of_value value =
  match Raw.view value with
  | Record record when Raw.same (Raw.get record "$$typeof") Mark.element -> Some record
  | _ -> None

let built kind key reference props =
  Raw.record
    [
      ("$$typeof", Mark.element);
      ("type", kind);
      ("key", Option.fold ~none:Raw.null ~some:Raw.of_any key);
      ("ref", reference);
      ("props", props);
      ("_owner", Raw.null);
    ]

let reserved name = match name with "key" | "ref" | "__self" | "__source" -> `Reserved | _ -> `Prop

let copied config =
  let props = Raw.make_object () in
  Option.iter
    (fun config ->
      Array.iter
        (fun name -> match reserved name with `Reserved -> () | `Prop -> Raw.set props name (Raw.get config name))
        (Raw.keys config))
    (Raw.present config);
  props

let defaults kind props =
  Option.iter
    (fun given ->
      Array.iter
        (fun name ->
          match Raw.view (Raw.get props name) with
          | Missing when Raw.same (Raw.get props name) Raw.undefined -> Raw.set props name (Raw.get given name)
          | _ -> ())
        (Raw.keys given))
    (Option.bind (Raw.present kind) (fun kind ->
         match Raw.view kind with Callable _ | Record _ -> Raw.find kind "defaultProps" | _ -> None))

let given_key config = Option.map Raw.text_of (Option.bind (Raw.present config) (fun config -> Raw.find config "key"))

let given_ref config =
  Option.value ~default:Raw.null (Option.bind (Raw.present config) (fun config -> Raw.find config "ref"))

let put_children props children =
  match children with
  | [||] -> ()
  | [| only |] -> Raw.set props "children" only
  | many -> Raw.set props "children" many

let create kind config children =
  let props = copied config in
  put_children props children;
  defaults kind props;
  built kind (given_key config) (given_ref config) props

let jsx kind config key =
  let props = copied config in
  defaults kind props;
  let key =
    match given_key config with
    | Some key -> Some key
    | None -> Option.map Raw.text_of (Raw.present key)
  in
  built kind key (given_ref config) props

let kind element = Raw.get element "type"
let props element = Raw.get element "props"
let reference element = Raw.get element "ref"
let key element = Option.map Raw.text_of (Raw.find element "key")

let clone element config children =
  let props = Raw.merged (Raw.make_object ()) (props element) Raw.undefined in
  let fallback = Option.bind (Raw.present (kind element)) (fun kind ->
    match Raw.view kind with Callable _ | Record _ -> Raw.find kind "defaultProps" | _ -> None) in
  Option.iter
    (fun config ->
      Array.iter
        (fun name ->
          match reserved name with
          | `Reserved -> ()
          | `Prop -> (
              let value = Raw.get config name in
              match (Raw.same value Raw.undefined, fallback) with
              | true, Some defaults -> Raw.set props name (Raw.get defaults name)
              | true, None | false, _ -> Raw.set props name value))
        (Raw.keys config))
    (Raw.present config);
  put_children props children;
  let key = match given_key config with Some key -> Some key | None -> key element in
  let reference =
    Option.fold ~none:(reference element) ~some:(fun config -> match Raw.find config "ref" with Some given -> given | None -> reference element)
      (Raw.present config)
  in
  built (kind element) key reference props

let rekeyed element key = built (kind element) (Some key) (reference element) (props element)
