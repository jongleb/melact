let version = "18.3.1"
let create kind config children = Element.create kind config children
let jsx kind config key = Element.jsx kind config key
let clone element config children = Element.clone element config children
let isValidElement value = Option.is_some (Element.of_value value)
let createRef () = Raw.record [ ("current", Raw.null) ]
let createContext default = Render.context default
let forwardRef render = Raw.record [ ("$$typeof", Element.Mark.forward_ref); ("render", render) ]

let memo kind compare =
  Raw.record [ ("$$typeof", Element.Mark.memo); ("type", kind); ("compare", Option.value ~default:Raw.null (Raw.present compare)) ]

let lazy_ load = Raw.record [ ("$$typeof", Element.Mark.lazy_); ("_payload", load) ]
let fragment = Element.Mark.fragment
let strictMode = Element.Mark.strict_mode
let profiler = Element.Mark.profiler
let suspense = Element.Mark.suspense

external replace_all : string -> string -> string -> string = "replaceAll" [@@mel.send]
let escape_slashes text = Js.String.replaceByRe ~regexp:[%re "/\\/+/g"] ~replacement:"$&/" text

external in_radix : int -> int -> string = "toString" [@@mel.send]

let escaped key = "$" ^ replace_all (replace_all key "=" "=0") ":" "=2"

let key_at value index =
  match Option.bind (Element.of_value value) Element.key with
  | Some key -> escaped key
  | None -> in_radix index 36

let rec into children out prefix name callback =
  let children = match Raw.view children with Flag _ -> Raw.null | _ -> children in
  let leaf =
    match Raw.view children with
    | Missing | Text _ | Number _ -> `Leaf
    | Record record ->
        let mark = Raw.get record "$$typeof" in
        (match Raw.same mark Element.Mark.element || Raw.same mark Element.Mark.portal with
        | true -> `Leaf
        | false -> (
            match (Raw.view (Raw.get record "build"), Raw.view (Raw.get record "patch")) with
            | Callable _, Callable _ -> `Leaf
            | _ -> Js.Exn.raiseError "Objects are not valid as a React child"))
    | Listed items -> `Items items
    | Callable _ | Flag _ | Other _ -> `Skipped
  in
  match leaf with
  | `Skipped -> 0
  | `Leaf ->
      let mapped = callback children in
      let own = match name with "" -> "." ^ key_at children 0 | given -> given in
      (match Raw.view mapped with
      | Listed _ -> ignore (into mapped out (escape_slashes own ^ "/") "" (fun child -> child))
      | Missing -> ()
      | _ ->
          out :=
            Option.fold ~none:mapped
              ~some:(fun element ->
                let kept =
                  match (Element.key element, Option.bind (Element.of_value children) Element.key) with
                  | Some key, Some original when String.equal key original -> ""
                  | Some key, _ -> escape_slashes key ^ "/"
                  | None, _ -> ""
                in
                Element.rekeyed element (prefix ^ kept ^ own))
              (Element.of_value mapped)
            :: !out);
      1
  | `Items items ->
      let next = match name with "" -> "." | given -> given ^ ":" in
      let total = ref 0 in
      Array.iteri (fun index item -> total := !total + into item out prefix (next ^ key_at item index) callback) items;
      !total

let mapped children apply =
  match Raw.present children with
  | None -> children
  | Some children ->
      let out = ref [] and count = ref 0 in
      ignore
        (into children out "" "" (fun child ->
             let result = apply child !count in
             incr count;
             result));
      Raw.list_of (Array.of_list (List.rev !out))

let childrenMap children apply context = mapped children (fun child index -> Raw.call_on apply context [| child; Raw.of_any index |])

let childrenForEach children apply context =
  ignore
    (mapped children (fun child index ->
         ignore (Raw.call_on apply context [| child; Raw.of_any index |]);
         Raw.undefined))

let childrenCount children =
  let count = ref 0 in
  ignore (mapped children (fun _ _ -> incr count; Raw.undefined));
  !count

let childrenToArray children = match Raw.present children with None -> Raw.list_of [||] | Some _ -> mapped children (fun child _ -> child)

let childrenOnly children =
  match Element.of_value children with
  | Some element -> element
  | None -> Js.Exn.raiseError "React.Children.only expected to receive a single React element child."

let settled () = ignore (React.act (fun () -> ()))
