(** reason-react's [ReactDOMTestUtils] for Melact. [Simulate] sends the native event that Melact's
    handler for the prop listens to ([change] is [input], [focus] is [focusin], [blur] is
    [focusout]) to the element; an event given with [...WithEvent] lends it its fields, and a
    [target] in it writes its [value] or [checked] to the element first. *)

val act : (unit -> unit) -> unit [@@deprecated "use React.act instead"]
val actAsync : (unit -> 'a Js.Promise.t) -> unit Js.Promise.t [@@deprecated "use React.actAsync instead"]
val isElement : 'element -> bool [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]

(** Melact keeps no component type on an element, so this raises, as [React.cloneElement] does. *)
val isElementOfType : 'element -> 'props React.component -> bool [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]

val isDOMComponent : 'element -> bool [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]

(** Melact has no class components: nothing is a composite component instance. *)
val isCompositeComponent : 'element -> bool [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]

val isCompositeComponentWithType : 'element -> 'props React.component -> bool [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]

module Simulate : sig
  val click : Dom.element -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val clickWithEvent : Dom.element -> 'event -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val change : Dom.element -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val blur : Dom.element -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val changeWithEvent : Dom.element -> 'event -> unit
  val changeWithValue : Dom.element -> string -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val changeWithChecked : Dom.element -> bool -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val canPlay : Dom.element -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val timeUpdate : Dom.element -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val ended : Dom.element -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
  val focus : Dom.element -> unit
end

module DOM : sig
  external value : Dom.element -> string option = "value" [@@mel.return nullable] [@@mel.get] [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-webapi instead."]

  val findBySelector : Dom.element -> string -> Dom.element option [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-webapi instead."]
  val findByAllSelector : Dom.element -> string -> Dom.element array [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-webapi instead."]
  val findBySelectorAndTextContent : Dom.element -> string -> string -> Dom.element option [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-webapi instead."]
  val findBySelectorAndPartialTextContent : Dom.element -> string -> string -> Dom.element option [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-webapi instead."]
end

val prepareContainer : Dom.element option ref -> unit -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
val cleanupContainer : Dom.element option ref -> unit -> unit [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
val getContainer : Dom.element option ref -> Dom.element [@@deprecated "ReactDOMTestUtils is deprecated, and will be removed in next version. Please use melange-testing-library instead."]
