type t

type view =
  | Missing
  | Flag of bool
  | Number of float
  | Text of string
  | Callable of t
  | Listed of t array
  | Record of t
  | Other of t

external of_any : 'a -> t = "%identity"
external to_any : t -> 'a = "%identity"
external get : t -> string -> t = "" [@@mel.get_index]
external set : t -> string -> 'a -> unit = "" [@@mel.set_index]
external same : t -> t -> bool = "is" [@@mel.scope "Object"]
external keys : t -> string array = "keys" [@@mel.scope "Object"]
external undefined : t = "undefined"
external null : t = "null"
external symbol : string -> t = "for" [@@mel.scope "Symbol"]
external call0 : t -> (_[@mel.as {json|undefined|json}]) -> t = "call" [@@mel.send]
external call1 : t -> (_[@mel.as {json|undefined|json}]) -> t -> t = "call" [@@mel.send]
external call2 : t -> (_[@mel.as {json|undefined|json}]) -> t -> t -> t = "call" [@@mel.send]
external call3 : t -> (_[@mel.as {json|undefined|json}]) -> t -> t -> t -> t = "call" [@@mel.send]
external call_on : t -> t -> t array -> t = "apply" [@@mel.send]
external construct : t -> t array -> t = "construct" [@@mel.scope "Reflect"]
external text_of : t -> string = "String"
external merged : t -> t -> t -> t = "assign" [@@mel.scope "Object"]
external make_object : unit -> t = "Object" [@@mel.new]
external list_of : t array -> t = "%identity"
external own : t -> string -> bool = "hasOwn" [@@mel.scope "Object"]

external is_array : t -> bool = "isArray" [@@mel.scope "Array"]

let view value =
  match Js.typeof value with
  | "undefined" -> Missing
  | "boolean" -> Flag (to_any value)
  | "number" -> Number (to_any value)
  | "string" -> Text (to_any value)
  | "function" -> Callable value
  | "object" when same value null -> Missing
  | "object" when is_array value -> Listed (to_any value)
  | "object" -> Record value
  | _ -> Other value

let present value = match view value with Missing -> None | _ -> Some value
let find value name = present (get value name)

let record fields =
  let made = make_object () in
  List.iter (fun (name, value) -> set made name value) fields;
  made

let shallow first second =
  match same first second with
  | true -> Melhole.View.Unchanged
  | false -> (
      match (view first, view second) with
      | Record _, Record _ ->
          let named = keys first in
          let equal =
            Array.length named = Array.length (keys second)
            && Array.for_all (fun name -> own second name && same (get first name) (get second name)) named
          in
          (match equal with true -> Melhole.View.Unchanged | false -> Melhole.View.Changed)
      | _ -> Melhole.View.Changed)

type 'value table

external table : unit -> 'value table = "WeakMap" [@@mel.new]
external table_get : 'value table -> t -> 'value Js.undefined = "get" [@@mel.send]
external store : 'value table -> t -> 'value -> unit = "set" [@@mel.send]

let lookup table key = Js.Undefined.toOption (table_get table key)
