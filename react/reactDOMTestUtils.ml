external document : Dom.document = "document"
external create_element : Dom.document -> string -> Dom.element = "createElement" [@@mel.send]
external body : Dom.document -> Dom.element option = "body" [@@mel.return nullable] [@@mel.get]
external append_child : Dom.element -> Dom.element -> unit = "appendChild" [@@mel.send]
external remove : Dom.element -> unit = "remove" [@@mel.send]
external query_all : Dom.element -> string -> Dom.nodeList = "querySelectorAll" [@@mel.send]
external elements : Dom.nodeList -> Dom.element array = "from" [@@mel.scope "Array"]
external text_content : Dom.element -> string = "textContent" [@@mel.get]

let sent : string -> Dom.element -> 'event Js.undefined -> unit =
  [%mel.raw
    {|function (type, element, given) {
  var event = new Event(type, { bubbles: true, cancelable: true });
  if (given !== undefined) {
    Object.keys(given).forEach(function (name) {
      var value = given[name];
      if (name === "target") {
        if (value != null && "value" in value) element.value = value.value;
        if (value != null && "checked" in value) element.checked = value.checked;
      } else {
        Object.defineProperty(event, name, { value: value });
      }
    });
  }
  element.dispatchEvent(event);
}|}]

let act run = ignore (React.act run)
let actAsync run = React.actAsync (fun () -> Js.Promise.then_ (fun _ -> Js.Promise.resolve ()) (run ()))

let isElement : 'element -> bool =
  [%mel.raw {|function (value) { return value != null && typeof value === "object" && typeof value.build === "function" && typeof value.patch === "function"; }|}]

let isElementOfType _ _ =
  Js.Exn.raiseError "melact: ReactDOMTestUtils.isElementOfType is not supported; an element keeps no component type"

let isDOMComponent : 'element -> bool =
  [%mel.raw {|function (value) { return value != null && typeof value === "object" && value.nodeType === 1; }|}]

let isCompositeComponent _ = false
let isCompositeComponentWithType _ _ = false

module Simulate = struct
  let click element = sent "click" element Js.undefined
  let clickWithEvent element event = sent "click" element (Js.Undefined.return event)
  let change element = sent "input" element Js.undefined
  let blur element = sent "focusout" element Js.undefined
  let changeWithEvent element event = sent "input" element (Js.Undefined.return event)
  let changeWithValue element value = changeWithEvent element [%mel.obj { target = [%mel.obj { value }] }]
  let changeWithChecked element checked = changeWithEvent element [%mel.obj { target = [%mel.obj { checked }] }]
  let canPlay element = sent "canplay" element Js.undefined
  let timeUpdate element = sent "timeupdate" element Js.undefined
  let ended element = sent "ended" element Js.undefined
  let focus element = sent "focusin" element Js.undefined
end

module DOM = struct
  external value : Dom.element -> string option = "value" [@@mel.return nullable] [@@mel.get]

  external findBySelector : Dom.element -> string -> Dom.element option = "querySelector"
  [@@mel.return nullable] [@@mel.send]

  let findByAllSelector element selector = elements (query_all element selector)

  let findBySelectorAndTextContent element selector content =
    Array.find_opt (fun node -> String.equal (text_content node) content) (elements (query_all element selector))

  let findBySelectorAndPartialTextContent element selector content =
    Array.find_opt
      (fun node -> Js.String.includes ~search:content (text_content node))
      (elements (query_all element selector))
end

let prepareContainer container () =
  let made = create_element document "div" in
  Option.iter (fun body -> append_child body made) (body document);
  container := Some made

let cleanupContainer container () =
  Option.iter remove !container;
  container := None

let getContainer container = Option.get !container
