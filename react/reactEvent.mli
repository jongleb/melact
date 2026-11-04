(** reason-react's [ReactEvent] for melact: native DOM events, one type per
    event family so handlers keep reason-react's types. *)

(** What every event family offers. *)
module type Family = sig
  (** A native event of this family. *)
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

module Synthetic : Family
module Animation : Family
module Clipboard : Family
module Composition : Family
module Drag : Family
module Focus : Family
module Form : Family
module Image : Family
module Media : Family
module Selection : Family
module Transition : Family
module UI : Family
module Wheel : Family

module Keyboard : sig
  include Family

  val key : t -> string
  val code : t -> string
  val altKey : t -> bool
  val ctrlKey : t -> bool
  val metaKey : t -> bool
  val shiftKey : t -> bool
  val repeat : t -> bool
end

module Mouse : sig
  include Family

  val button : t -> int
  val clientX : t -> int
  val clientY : t -> int
  val pageX : t -> int
  val pageY : t -> int
  val altKey : t -> bool
  val ctrlKey : t -> bool
  val metaKey : t -> bool
  val shiftKey : t -> bool
end

module Pointer : sig
  include Family

  val pointerId : t -> int
  val pointerType : t -> string
  val clientX : t -> int
  val clientY : t -> int
end

module Touch : Family
