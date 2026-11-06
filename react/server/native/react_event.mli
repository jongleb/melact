(** React's synthetic events, as reason-react declares them, on a native server: typed, never fired. *)

type 'a synthetic

(** What a compiled handler receives; nothing builds one on a server. *)
type native

val ofNative : native -> 'a synthetic

module Synthetic : sig
  type tag
  type t = tag synthetic
  val bubbles : 'a synthetic -> bool
  val cancelable : 'a synthetic -> bool
  val currentTarget : 'a synthetic -> unit
  val defaultPrevented : 'a synthetic -> bool
  val eventPhase : 'a synthetic -> int
  val isTrusted : 'a synthetic -> bool
  val nativeEvent : 'a synthetic -> unit
  val preventDefault : 'a synthetic -> unit
  val isDefaultPrevented : 'a synthetic -> bool
  val stopPropagation : 'a synthetic -> unit
  val isPropagationStopped : 'a synthetic -> bool
  val target : 'a synthetic -> unit
  val timeStamp : 'a synthetic -> float
  val type_ : 'a synthetic -> string
  val persist : 'a synthetic -> unit
end

module Clipboard : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val clipboardData : t -> unit
end

module Composition : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val data : t -> string
end

module Drag : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val altKey : t -> bool
  val button : t -> int
  val buttons : t -> int
  val clientX : t -> int
  val clientY : t -> int
  val ctrlKey : t -> bool
  val getModifierState : t -> string -> bool
  val metaKey : t -> bool
  val movementX : t -> int
  val movementY : t -> int
  val pageX : t -> int
  val pageY : t -> int
  val relatedTarget : t -> unit option
  val screenX : t -> int
  val screenY : t -> int
  val shiftKey : t -> bool
  val dataTransfer : t -> unit
end

module Keyboard : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val altKey : t -> bool
  val charCode : t -> int
  val ctrlKey : t -> bool
  val getModifierState : t -> string -> bool
  val key : t -> string
  val keyCode : t -> int
  val locale : t -> string
  val location : t -> int
  val metaKey : t -> bool
  val repeat : t -> bool
  val shiftKey : t -> bool
  val which : t -> int
end

module Focus : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val relatedTarget : t -> unit option
end

module Form : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
end

module Mouse : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val altKey : t -> bool
  val button : t -> int
  val buttons : t -> int
  val clientX : t -> int
  val clientY : t -> int
  val ctrlKey : t -> bool
  val getModifierState : t -> string -> bool
  val metaKey : t -> bool
  val movementX : t -> int
  val movementY : t -> int
  val pageX : t -> int
  val pageY : t -> int
  val relatedTarget : t -> unit option
  val screenX : t -> int
  val screenY : t -> int
  val shiftKey : t -> bool
end

module Pointer : sig
  type tag
  type t = tag synthetic
  val type_ : t -> string
  val target : t -> unit
  val currentTarget : t -> unit
  val eventPhase : t -> int
  val stopPropagation : t -> unit
  val bubbles : t -> bool
  val cancelable : t -> bool
  val preventDefault : t -> unit
  val defaultPrevented : t -> bool
  val isTrusted : t -> bool
  val timeStamp : t -> float
  val nativeEvent : t -> unit
  val isDefaultPrevented : t -> bool
  val isPropagationStopped : t -> bool
  val persist : t -> unit
  val detail : t -> int
  val view : t -> unit
  val screenX : t -> int
  val screenY : t -> int
  val clientX : t -> int
  val clientY : t -> int
  val pageX : t -> int
  val pageY : t -> int
  val movementX : t -> int
  val movementY : t -> int
  val ctrlKey : t -> bool
  val shiftKey : t -> bool
  val altKey : t -> bool
  val metaKey : t -> bool
  val getModifierState : t -> string -> bool
  val button : t -> int
  val buttons : t -> int
  val relatedTarget : t -> unit option
  val pointerId : t -> int
  val width : t -> float
  val height : t -> float
  val pressure : t -> float
  val tangentialPressure : t -> float
  val tiltX : t -> int
  val tiltY : t -> int
  val twist : t -> int
  val pointerType : t -> string
  val isPrimary : t -> bool
end

module Selection : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
end

module Touch : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val altKey : t -> bool
  val changedTouches : t -> unit
  val ctrlKey : t -> bool
  val getModifierState : t -> string -> bool
  val metaKey : t -> bool
  val shiftKey : t -> bool
  val targetTouches : t -> unit
  val touches : t -> unit
end

module UI : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val detail : t -> int
  val view : t -> unit
end

module Wheel : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val deltaMode : t -> int
  val deltaX : t -> float
  val deltaY : t -> float
  val deltaZ : t -> float
end

module Media : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
end

module Image : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
end

module Animation : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val animationName : t -> string
  val pseudoElement : t -> string
  val elapsedTime : t -> float
end

module Transition : sig
  type tag
  type t = tag synthetic
  val bubbles : t -> bool
  val cancelable : t -> bool
  val currentTarget : t -> unit
  val defaultPrevented : t -> bool
  val eventPhase : t -> int
  val isTrusted : t -> bool
  val nativeEvent : t -> unit
  val preventDefault : t -> unit
  val isDefaultPrevented : t -> bool
  val stopPropagation : t -> unit
  val isPropagationStopped : t -> bool
  val target : t -> unit
  val timeStamp : t -> float
  val type_ : t -> string
  val persist : t -> unit
  val propertyName : t -> string
  val pseudoElement : t -> string
  val elapsedTime : t -> float
end

val toSyntheticEvent : 'a synthetic -> Synthetic.t
