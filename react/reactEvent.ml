module type Family = sig
  type t = Native of Dom.event [@@unboxed]

  val target : t -> < .. > Js.t
  val type_ : t -> string
  val timeStamp : t -> float
  val bubbles : t -> bool
  val defaultPrevented : t -> bool
  val preventDefault : t -> unit
  val stopPropagation : t -> unit
  val nativeEvent : t -> < .. > Js.t
end

external target : Dom.event -> < .. > Js.t = "target" [@@mel.get]
external type_ : Dom.event -> string = "type" [@@mel.get]
external time_stamp : Dom.event -> float = "timeStamp" [@@mel.get]
external bubbles : Dom.event -> bool = "bubbles" [@@mel.get]
external default_prevented : Dom.event -> bool = "defaultPrevented" [@@mel.get]
external prevent_default : Dom.event -> unit = "preventDefault" [@@mel.send]
external stop_propagation : Dom.event -> unit = "stopPropagation" [@@mel.send]
external native : Dom.event -> < .. > Js.t = "%identity"
external string_field : Dom.event -> string -> string = "" [@@mel.get_index]
external int_field : Dom.event -> string -> int = "" [@@mel.get_index]
external bool_field : Dom.event -> string -> bool = "" [@@mel.get_index]

module Make () = struct
  type t = Native of Dom.event [@@unboxed]

  let target (Native event) = target event
  let type_ (Native event) = type_ event
  let timeStamp (Native event) = time_stamp event
  let bubbles (Native event) = bubbles event
  let defaultPrevented (Native event) = default_prevented event
  let preventDefault (Native event) = prevent_default event
  let stopPropagation (Native event) = stop_propagation event
  let nativeEvent (Native event) = native event
end

module Synthetic = Make ()
module Animation = Make ()
module Clipboard = Make ()
module Composition = Make ()
module Drag = Make ()
module Focus = Make ()
module Form = Make ()
module Image = Make ()
module Media = Make ()
module Selection = Make ()
module Transition = Make ()
module UI = Make ()
module Wheel = Make ()
module Touch = Make ()

module Keyboard = struct
  include Make ()

  let key (Native event) = string_field event "key"
  let code (Native event) = string_field event "code"
  let altKey (Native event) = bool_field event "altKey"
  let ctrlKey (Native event) = bool_field event "ctrlKey"
  let metaKey (Native event) = bool_field event "metaKey"
  let shiftKey (Native event) = bool_field event "shiftKey"
  let repeat (Native event) = bool_field event "repeat"
end

module Mouse = struct
  include Make ()

  let button (Native event) = int_field event "button"
  let clientX (Native event) = int_field event "clientX"
  let clientY (Native event) = int_field event "clientY"
  let pageX (Native event) = int_field event "pageX"
  let pageY (Native event) = int_field event "pageY"
  let altKey (Native event) = bool_field event "altKey"
  let ctrlKey (Native event) = bool_field event "ctrlKey"
  let metaKey (Native event) = bool_field event "metaKey"
  let shiftKey (Native event) = bool_field event "shiftKey"
end

module Pointer = struct
  include Make ()

  let pointerId (Native event) = int_field event "pointerId"
  let pointerType (Native event) = string_field event "pointerType"
  let clientX (Native event) = int_field event "clientX"
  let clientY (Native event) = int_field event "clientY"
end
