external describe : string -> (unit -> unit) -> unit = "describe"
external test : string -> (unit -> unit) -> unit = "test"

type 'a expectation

external expect : 'a -> 'a expectation = "expect"
external to_be : 'a expectation -> 'a -> unit = "toBe" [@@mel.send]
external to_equal : 'a expectation -> 'a -> unit = "toEqual" [@@mel.send]

external to_throw : (unit -> 'a) expectation -> string -> unit = "toThrow"
[@@mel.send]

type spy
type mock
type prototype

external element_prototype : prototype = "prototype" [@@mel.scope "Element"]
external node_prototype : prototype = "prototype" [@@mel.scope "Node"]

external event_target_prototype : prototype = "prototype"
[@@mel.scope "EventTarget"]
external spy_on : prototype -> string -> spy = "spyOn" [@@mel.scope "vi"]
external restore : spy -> unit = "mockRestore" [@@mel.send]
external mock : spy -> mock = "mock" [@@mel.get]
external calls : mock -> string array array = "calls" [@@mel.get]

external document : Dom.document = "document"
external body : Dom.document -> Dom.element = "body" [@@mel.get]

external create_element : Dom.document -> string -> Dom.element
  = "createElement"
[@@mel.send]

external append_child : Dom.element -> Dom.element -> unit = "appendChild"
[@@mel.send]

external inner_html : Dom.element -> string = "innerHTML" [@@mel.get]

external select : Dom.element -> string -> Dom.element = "querySelector"
[@@mel.send]

external click : Dom.element -> unit = "click" [@@mel.send]
external child_nodes : Dom.element -> Dom.nodeList = "childNodes" [@@mel.get]
external nodes : Dom.nodeList -> Dom.node array = "from" [@@mel.scope "Array"]
external text_content : 'a Dom.node_like -> string = "textContent" [@@mel.get]
external property : Dom.element -> string -> 'a = "" [@@mel.get_index]
external style : Dom.element -> Dom.cssStyleDeclaration = "style" [@@mel.get]

external style_property : Dom.cssStyleDeclaration -> string -> string = ""
[@@mel.get_index]
external event : string -> Dom.event = "Event" [@@mel.new]
external dispatch : Dom.element -> Dom.event -> unit = "dispatchEvent" [@@mel.send]
external stop_propagation : Dom.event -> unit = "stopPropagation" [@@mel.send]
external same : 'a -> 'b -> bool = "%eq"

let attached () =
  let root = create_element document "div" in
  append_child (body document) root;
  root

let count_calls spy run =
  run ();
  let count = Array.length (calls (mock spy)) in
  restore spy;
  count
