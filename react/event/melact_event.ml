type 'a synthetic
external ofNative : Dom.event -> 'a synthetic = "%identity"
module Synthetic =
struct
  type tag
  type t = tag synthetic
  external bubbles : 'a synthetic -> bool = "bubbles"[@@mel.get]
  external cancelable : 'a synthetic -> bool = "cancelable"[@@mel.get]
  external currentTarget :
    'a synthetic -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : 'a synthetic -> bool = "defaultPrevented"
  [@@mel.get]
  external eventPhase : 'a synthetic -> int = "eventPhase"[@@mel.get]
  external isTrusted : 'a synthetic -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : 'a synthetic -> < .. >  Js.t = "%identity"
  external preventDefault : 'a synthetic -> unit = "preventDefault"
  [@@mel.send]
  external isDefaultPrevented : 'a synthetic -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : 'a synthetic -> unit = "stopPropagation"
  [@@mel.send]
  external isPropagationStopped : 'a synthetic -> bool = "cancelBubble" [@@mel.get]
  external target : 'a synthetic -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : 'a synthetic -> float = "timeStamp"[@@mel.get]
  external type_ : 'a synthetic -> string = "type"[@@mel.get]
  external persist : 'a synthetic -> unit = "%ignore"
end
external toSyntheticEvent : 'a synthetic -> Synthetic.t = "%identity"
module Clipboard =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external clipboardData : t -> < .. >  Js.t = "clipboardData"[@@mel.get]
end
module Composition =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external data : t -> string = "data"[@@mel.get]
end
module Drag =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external altKey : t -> bool = "altKey"[@@mel.get]
  external button : t -> int = "button"[@@mel.get]
  external buttons : t -> int = "buttons"[@@mel.get]
  external clientX : t -> int = "clientX"[@@mel.get]
  external clientY : t -> int = "clientY"[@@mel.get]
  external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
  external getModifierState : t -> string -> bool = "getModifierState"
  [@@mel.send]
  external metaKey : t -> bool = "metaKey"[@@mel.get]
  external movementX : t -> int = "movementX"[@@mel.get]
  external movementY : t -> int = "movementY"[@@mel.get]
  external pageX : t -> int = "pageX"[@@mel.get]
  external pageY : t -> int = "pageY"[@@mel.get]
  external relatedTarget : t -> < .. >  Js.t option = "relatedTarget"
  [@@mel.get][@@mel.return nullable]
  external screenX : t -> int = "screenX"[@@mel.get]
  external screenY : t -> int = "screenY"[@@mel.get]
  external shiftKey : t -> bool = "shiftKey"[@@mel.get]
  external dataTransfer : t -> < .. >  Js.t = "dataTransfer"[@@mel.get]
end
module Keyboard =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external altKey : t -> bool = "altKey"[@@mel.get]
  external charCode : t -> int = "charCode"[@@mel.get]
  external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
  external getModifierState : t -> string -> bool = "getModifierState"
  [@@mel.send]
  external key : t -> string = "key"[@@mel.get]
  external keyCode : t -> int = "keyCode"[@@mel.get]
  external locale : t -> string = "locale"[@@mel.get]
  external location : t -> int = "location"[@@mel.get]
  external metaKey : t -> bool = "metaKey"[@@mel.get]
  external repeat : t -> bool = "repeat"[@@mel.get]
  external shiftKey : t -> bool = "shiftKey"[@@mel.get]
  external which : t -> int = "which"[@@mel.get]
end
module Focus =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external relatedTarget : t -> < .. >  Js.t option = "relatedTarget"
  [@@mel.get][@@mel.return nullable]
end
module Form =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
end
module Mouse =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external altKey : t -> bool = "altKey"[@@mel.get]
  external button : t -> int = "button"[@@mel.get]
  external buttons : t -> int = "buttons"[@@mel.get]
  external clientX : t -> int = "clientX"[@@mel.get]
  external clientY : t -> int = "clientY"[@@mel.get]
  external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
  external getModifierState : t -> string -> bool = "getModifierState"
  [@@mel.send]
  external metaKey : t -> bool = "metaKey"[@@mel.get]
  external movementX : t -> int = "movementX"[@@mel.get]
  external movementY : t -> int = "movementY"[@@mel.get]
  external pageX : t -> int = "pageX"[@@mel.get]
  external pageY : t -> int = "pageY"[@@mel.get]
  external relatedTarget : t -> < .. >  Js.t option = "relatedTarget"
  [@@mel.get][@@mel.return nullable]
  external screenX : t -> int = "screenX"[@@mel.get]
  external screenY : t -> int = "screenY"[@@mel.get]
  external shiftKey : t -> bool = "shiftKey"[@@mel.get]
end
module Pointer =
struct
  type tag
  type t = tag synthetic
  external type_ : t -> string = "type"[@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external persist : t -> unit = "%ignore"
  external detail : t -> int = "detail"[@@mel.get]
  external view : t -> Dom.window = "view"[@@mel.get]
  external screenX : t -> int = "screenX"[@@mel.get]
  external screenY : t -> int = "screenY"[@@mel.get]
  external clientX : t -> int = "clientX"[@@mel.get]
  external clientY : t -> int = "clientY"[@@mel.get]
  external pageX : t -> int = "pageX"[@@mel.get]
  external pageY : t -> int = "pageY"[@@mel.get]
  external movementX : t -> int = "movementX"[@@mel.get]
  external movementY : t -> int = "movementY"[@@mel.get]
  external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
  external shiftKey : t -> bool = "shiftKey"[@@mel.get]
  external altKey : t -> bool = "altKey"[@@mel.get]
  external metaKey : t -> bool = "metaKey"[@@mel.get]
  external getModifierState : t -> string -> bool = "getModifierState"
  [@@mel.send]
  external button : t -> int = "button"[@@mel.get]
  external buttons : t -> int = "buttons"[@@mel.get]
  external relatedTarget : t -> < .. >  Js.t option = "relatedTarget"
  [@@mel.get][@@mel.return nullable]
  external pointerId : t -> Dom.eventPointerId = "pointerId"[@@mel.get]
  external width : t -> float = "width"[@@mel.get]
  external height : t -> float = "height"[@@mel.get]
  external pressure : t -> float = "pressure"[@@mel.get]
  external tangentialPressure : t -> float = "tangentialPressure"
  [@@mel.get]
  external tiltX : t -> int = "tiltX"[@@mel.get]
  external tiltY : t -> int = "tiltY"[@@mel.get]
  external twist : t -> int = "twist"[@@mel.get]
  external pointerType : t -> string = "pointerType"[@@mel.get]
  external isPrimary : t -> bool = "isPrimary"[@@mel.get]
end
module Selection =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
end
module Touch =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external altKey : t -> bool = "altKey"[@@mel.get]
  external changedTouches : t -> < .. >  Js.t = "changedTouches"
  [@@mel.get]
  external ctrlKey : t -> bool = "ctrlKey"[@@mel.get]
  external getModifierState : t -> string -> bool = "getModifierState"
  [@@mel.send]
  external metaKey : t -> bool = "metaKey"[@@mel.get]
  external shiftKey : t -> bool = "shiftKey"[@@mel.get]
  external targetTouches : t -> < .. >  Js.t = "targetTouches"[@@mel.get]
  external touches : t -> < .. >  Js.t = "touches"[@@mel.get]
end
module UI =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external detail : t -> int = "detail"[@@mel.get]
  external view : t -> Dom.window = "view"[@@mel.get]
end
module Wheel =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external deltaMode : t -> int = "deltaMode"[@@mel.get]
  external deltaX : t -> float = "deltaX"[@@mel.get]
  external deltaY : t -> float = "deltaY"[@@mel.get]
  external deltaZ : t -> float = "deltaZ"[@@mel.get]
end
module Media =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
end
module Image =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
end
module Animation =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external animationName : t -> string = "animationName"[@@mel.get]
  external pseudoElement : t -> string = "pseudoElement"[@@mel.get]
  external elapsedTime : t -> float = "elapsedTime"[@@mel.get]
end
module Transition =
struct
  type tag
  type t = tag synthetic
  external bubbles : t -> bool = "bubbles"[@@mel.get]
  external cancelable : t -> bool = "cancelable"[@@mel.get]
  external currentTarget : t -> < .. >  Js.t = "currentTarget"[@@mel.get]
  external defaultPrevented : t -> bool = "defaultPrevented"[@@mel.get]
  external eventPhase : t -> int = "eventPhase"[@@mel.get]
  external isTrusted : t -> bool = "isTrusted"[@@mel.get]
  external nativeEvent : t -> < .. >  Js.t = "%identity"
  external preventDefault : t -> unit = "preventDefault"[@@mel.send]
  external isDefaultPrevented : t -> bool = "defaultPrevented" [@@mel.get]
  external stopPropagation : t -> unit = "stopPropagation"[@@mel.send]
  external isPropagationStopped : t -> bool = "cancelBubble" [@@mel.get]
  external target : t -> < .. >  Js.t = "target"[@@mel.get]
  external timeStamp : t -> float = "timeStamp"[@@mel.get]
  external type_ : t -> string = "type"[@@mel.get]
  external persist : t -> unit = "%ignore"
  external propertyName : t -> string = "propertyName"[@@mel.get]
  external pseudoElement : t -> string = "pseudoElement"[@@mel.get]
  external elapsedTime : t -> float = "elapsedTime"[@@mel.get]
end
