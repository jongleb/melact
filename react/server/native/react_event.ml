type 'a synthetic = Never_fired
type native

external ofNative : native -> 'a synthetic = "%identity"

module Synthetic = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Synthetic.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Synthetic.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Synthetic.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Synthetic.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Synthetic.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Synthetic.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Synthetic.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Synthetic.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Synthetic.type_: no event happens on a server")
  let persist _ = ()
end

module Clipboard = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Clipboard.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Clipboard.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Clipboard.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Clipboard.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Clipboard.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Clipboard.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Clipboard.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Clipboard.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Clipboard.type_: no event happens on a server")
  let persist _ = ()
  let clipboardData _ = ()
end

module Composition = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Composition.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Composition.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Composition.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Composition.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Composition.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Composition.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Composition.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Composition.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Composition.type_: no event happens on a server")
  let persist _ = ()
  let data _ = raise (Invalid_argument "React.Event.Composition.data: no event happens on a server")
end

module Drag = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Drag.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Drag.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Drag.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Drag.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Drag.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Drag.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Drag.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Drag.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Drag.type_: no event happens on a server")
  let persist _ = ()
  let altKey _ = raise (Invalid_argument "React.Event.Drag.altKey: no event happens on a server")
  let button _ = raise (Invalid_argument "React.Event.Drag.button: no event happens on a server")
  let buttons _ = raise (Invalid_argument "React.Event.Drag.buttons: no event happens on a server")
  let clientX _ = raise (Invalid_argument "React.Event.Drag.clientX: no event happens on a server")
  let clientY _ = raise (Invalid_argument "React.Event.Drag.clientY: no event happens on a server")
  let ctrlKey _ = raise (Invalid_argument "React.Event.Drag.ctrlKey: no event happens on a server")
  let getModifierState _ _ = raise (Invalid_argument "React.Event.Drag.getModifierState: no event happens on a server")
  let metaKey _ = raise (Invalid_argument "React.Event.Drag.metaKey: no event happens on a server")
  let movementX _ = raise (Invalid_argument "React.Event.Drag.movementX: no event happens on a server")
  let movementY _ = raise (Invalid_argument "React.Event.Drag.movementY: no event happens on a server")
  let pageX _ = raise (Invalid_argument "React.Event.Drag.pageX: no event happens on a server")
  let pageY _ = raise (Invalid_argument "React.Event.Drag.pageY: no event happens on a server")
  let relatedTarget _ = raise (Invalid_argument "React.Event.Drag.relatedTarget: no event happens on a server")
  let screenX _ = raise (Invalid_argument "React.Event.Drag.screenX: no event happens on a server")
  let screenY _ = raise (Invalid_argument "React.Event.Drag.screenY: no event happens on a server")
  let shiftKey _ = raise (Invalid_argument "React.Event.Drag.shiftKey: no event happens on a server")
  let dataTransfer _ = ()
end

module Keyboard = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Keyboard.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Keyboard.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Keyboard.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Keyboard.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Keyboard.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Keyboard.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Keyboard.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Keyboard.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Keyboard.type_: no event happens on a server")
  let persist _ = ()
  let altKey _ = raise (Invalid_argument "React.Event.Keyboard.altKey: no event happens on a server")
  let charCode _ = raise (Invalid_argument "React.Event.Keyboard.charCode: no event happens on a server")
  let ctrlKey _ = raise (Invalid_argument "React.Event.Keyboard.ctrlKey: no event happens on a server")
  let getModifierState _ _ = raise (Invalid_argument "React.Event.Keyboard.getModifierState: no event happens on a server")
  let key _ = raise (Invalid_argument "React.Event.Keyboard.key: no event happens on a server")
  let keyCode _ = raise (Invalid_argument "React.Event.Keyboard.keyCode: no event happens on a server")
  let locale _ = raise (Invalid_argument "React.Event.Keyboard.locale: no event happens on a server")
  let location _ = raise (Invalid_argument "React.Event.Keyboard.location: no event happens on a server")
  let metaKey _ = raise (Invalid_argument "React.Event.Keyboard.metaKey: no event happens on a server")
  let repeat _ = raise (Invalid_argument "React.Event.Keyboard.repeat: no event happens on a server")
  let shiftKey _ = raise (Invalid_argument "React.Event.Keyboard.shiftKey: no event happens on a server")
  let which _ = raise (Invalid_argument "React.Event.Keyboard.which: no event happens on a server")
end

module Focus = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Focus.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Focus.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Focus.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Focus.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Focus.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Focus.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Focus.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Focus.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Focus.type_: no event happens on a server")
  let persist _ = ()
  let relatedTarget _ = raise (Invalid_argument "React.Event.Focus.relatedTarget: no event happens on a server")
end

module Form = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Form.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Form.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Form.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Form.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Form.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Form.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Form.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Form.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Form.type_: no event happens on a server")
  let persist _ = ()
end

module Mouse = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Mouse.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Mouse.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Mouse.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Mouse.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Mouse.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Mouse.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Mouse.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Mouse.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Mouse.type_: no event happens on a server")
  let persist _ = ()
  let altKey _ = raise (Invalid_argument "React.Event.Mouse.altKey: no event happens on a server")
  let button _ = raise (Invalid_argument "React.Event.Mouse.button: no event happens on a server")
  let buttons _ = raise (Invalid_argument "React.Event.Mouse.buttons: no event happens on a server")
  let clientX _ = raise (Invalid_argument "React.Event.Mouse.clientX: no event happens on a server")
  let clientY _ = raise (Invalid_argument "React.Event.Mouse.clientY: no event happens on a server")
  let ctrlKey _ = raise (Invalid_argument "React.Event.Mouse.ctrlKey: no event happens on a server")
  let getModifierState _ _ = raise (Invalid_argument "React.Event.Mouse.getModifierState: no event happens on a server")
  let metaKey _ = raise (Invalid_argument "React.Event.Mouse.metaKey: no event happens on a server")
  let movementX _ = raise (Invalid_argument "React.Event.Mouse.movementX: no event happens on a server")
  let movementY _ = raise (Invalid_argument "React.Event.Mouse.movementY: no event happens on a server")
  let pageX _ = raise (Invalid_argument "React.Event.Mouse.pageX: no event happens on a server")
  let pageY _ = raise (Invalid_argument "React.Event.Mouse.pageY: no event happens on a server")
  let relatedTarget _ = raise (Invalid_argument "React.Event.Mouse.relatedTarget: no event happens on a server")
  let screenX _ = raise (Invalid_argument "React.Event.Mouse.screenX: no event happens on a server")
  let screenY _ = raise (Invalid_argument "React.Event.Mouse.screenY: no event happens on a server")
  let shiftKey _ = raise (Invalid_argument "React.Event.Mouse.shiftKey: no event happens on a server")
end

module Pointer = struct
  type tag
  type t = tag synthetic
  let type_ _ = raise (Invalid_argument "React.Event.Pointer.type_: no event happens on a server")
  let target _ = ()
  let currentTarget _ = ()
  let eventPhase _ = raise (Invalid_argument "React.Event.Pointer.eventPhase: no event happens on a server")
  let stopPropagation _ = ()
  let bubbles _ = raise (Invalid_argument "React.Event.Pointer.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Pointer.cancelable: no event happens on a server")
  let preventDefault _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Pointer.defaultPrevented: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Pointer.isTrusted: no event happens on a server")
  let timeStamp _ = raise (Invalid_argument "React.Event.Pointer.timeStamp: no event happens on a server")
  let nativeEvent _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Pointer.isDefaultPrevented: no event happens on a server")
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Pointer.isPropagationStopped: no event happens on a server")
  let persist _ = ()
  let detail _ = raise (Invalid_argument "React.Event.Pointer.detail: no event happens on a server")
  let view _ = ()
  let screenX _ = raise (Invalid_argument "React.Event.Pointer.screenX: no event happens on a server")
  let screenY _ = raise (Invalid_argument "React.Event.Pointer.screenY: no event happens on a server")
  let clientX _ = raise (Invalid_argument "React.Event.Pointer.clientX: no event happens on a server")
  let clientY _ = raise (Invalid_argument "React.Event.Pointer.clientY: no event happens on a server")
  let pageX _ = raise (Invalid_argument "React.Event.Pointer.pageX: no event happens on a server")
  let pageY _ = raise (Invalid_argument "React.Event.Pointer.pageY: no event happens on a server")
  let movementX _ = raise (Invalid_argument "React.Event.Pointer.movementX: no event happens on a server")
  let movementY _ = raise (Invalid_argument "React.Event.Pointer.movementY: no event happens on a server")
  let ctrlKey _ = raise (Invalid_argument "React.Event.Pointer.ctrlKey: no event happens on a server")
  let shiftKey _ = raise (Invalid_argument "React.Event.Pointer.shiftKey: no event happens on a server")
  let altKey _ = raise (Invalid_argument "React.Event.Pointer.altKey: no event happens on a server")
  let metaKey _ = raise (Invalid_argument "React.Event.Pointer.metaKey: no event happens on a server")
  let getModifierState _ _ = raise (Invalid_argument "React.Event.Pointer.getModifierState: no event happens on a server")
  let button _ = raise (Invalid_argument "React.Event.Pointer.button: no event happens on a server")
  let buttons _ = raise (Invalid_argument "React.Event.Pointer.buttons: no event happens on a server")
  let relatedTarget _ = raise (Invalid_argument "React.Event.Pointer.relatedTarget: no event happens on a server")
  let pointerId _ = raise (Invalid_argument "React.Event.Pointer.pointerId: no event happens on a server")
  let width _ = raise (Invalid_argument "React.Event.Pointer.width: no event happens on a server")
  let height _ = raise (Invalid_argument "React.Event.Pointer.height: no event happens on a server")
  let pressure _ = raise (Invalid_argument "React.Event.Pointer.pressure: no event happens on a server")
  let tangentialPressure _ = raise (Invalid_argument "React.Event.Pointer.tangentialPressure: no event happens on a server")
  let tiltX _ = raise (Invalid_argument "React.Event.Pointer.tiltX: no event happens on a server")
  let tiltY _ = raise (Invalid_argument "React.Event.Pointer.tiltY: no event happens on a server")
  let twist _ = raise (Invalid_argument "React.Event.Pointer.twist: no event happens on a server")
  let pointerType _ = raise (Invalid_argument "React.Event.Pointer.pointerType: no event happens on a server")
  let isPrimary _ = raise (Invalid_argument "React.Event.Pointer.isPrimary: no event happens on a server")
end

module Selection = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Selection.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Selection.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Selection.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Selection.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Selection.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Selection.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Selection.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Selection.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Selection.type_: no event happens on a server")
  let persist _ = ()
end

module Touch = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Touch.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Touch.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Touch.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Touch.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Touch.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Touch.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Touch.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Touch.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Touch.type_: no event happens on a server")
  let persist _ = ()
  let altKey _ = raise (Invalid_argument "React.Event.Touch.altKey: no event happens on a server")
  let changedTouches _ = ()
  let ctrlKey _ = raise (Invalid_argument "React.Event.Touch.ctrlKey: no event happens on a server")
  let getModifierState _ _ = raise (Invalid_argument "React.Event.Touch.getModifierState: no event happens on a server")
  let metaKey _ = raise (Invalid_argument "React.Event.Touch.metaKey: no event happens on a server")
  let shiftKey _ = raise (Invalid_argument "React.Event.Touch.shiftKey: no event happens on a server")
  let targetTouches _ = ()
  let touches _ = ()
end

module UI = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.UI.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.UI.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.UI.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.UI.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.UI.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.UI.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.UI.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.UI.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.UI.type_: no event happens on a server")
  let persist _ = ()
  let detail _ = raise (Invalid_argument "React.Event.UI.detail: no event happens on a server")
  let view _ = ()
end

module Wheel = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Wheel.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Wheel.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Wheel.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Wheel.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Wheel.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Wheel.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Wheel.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Wheel.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Wheel.type_: no event happens on a server")
  let persist _ = ()
  let deltaMode _ = raise (Invalid_argument "React.Event.Wheel.deltaMode: no event happens on a server")
  let deltaX _ = raise (Invalid_argument "React.Event.Wheel.deltaX: no event happens on a server")
  let deltaY _ = raise (Invalid_argument "React.Event.Wheel.deltaY: no event happens on a server")
  let deltaZ _ = raise (Invalid_argument "React.Event.Wheel.deltaZ: no event happens on a server")
end

module Media = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Media.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Media.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Media.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Media.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Media.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Media.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Media.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Media.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Media.type_: no event happens on a server")
  let persist _ = ()
end

module Image = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Image.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Image.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Image.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Image.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Image.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Image.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Image.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Image.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Image.type_: no event happens on a server")
  let persist _ = ()
end

module Animation = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Animation.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Animation.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Animation.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Animation.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Animation.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Animation.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Animation.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Animation.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Animation.type_: no event happens on a server")
  let persist _ = ()
  let animationName _ = raise (Invalid_argument "React.Event.Animation.animationName: no event happens on a server")
  let pseudoElement _ = raise (Invalid_argument "React.Event.Animation.pseudoElement: no event happens on a server")
  let elapsedTime _ = raise (Invalid_argument "React.Event.Animation.elapsedTime: no event happens on a server")
end

module Transition = struct
  type tag
  type t = tag synthetic
  let bubbles _ = raise (Invalid_argument "React.Event.Transition.bubbles: no event happens on a server")
  let cancelable _ = raise (Invalid_argument "React.Event.Transition.cancelable: no event happens on a server")
  let currentTarget _ = ()
  let defaultPrevented _ = raise (Invalid_argument "React.Event.Transition.defaultPrevented: no event happens on a server")
  let eventPhase _ = raise (Invalid_argument "React.Event.Transition.eventPhase: no event happens on a server")
  let isTrusted _ = raise (Invalid_argument "React.Event.Transition.isTrusted: no event happens on a server")
  let nativeEvent _ = ()
  let preventDefault _ = ()
  let isDefaultPrevented _ = raise (Invalid_argument "React.Event.Transition.isDefaultPrevented: no event happens on a server")
  let stopPropagation _ = ()
  let isPropagationStopped _ = raise (Invalid_argument "React.Event.Transition.isPropagationStopped: no event happens on a server")
  let target _ = ()
  let timeStamp _ = raise (Invalid_argument "React.Event.Transition.timeStamp: no event happens on a server")
  let type_ _ = raise (Invalid_argument "React.Event.Transition.type_: no event happens on a server")
  let persist _ = ()
  let propertyName _ = raise (Invalid_argument "React.Event.Transition.propertyName: no event happens on a server")
  let pseudoElement _ = raise (Invalid_argument "React.Event.Transition.pseudoElement: no event happens on a server")
  let elapsedTime _ = raise (Invalid_argument "React.Event.Transition.elapsedTime: no event happens on a server")
end

let toSyntheticEvent Never_fired = Never_fired
