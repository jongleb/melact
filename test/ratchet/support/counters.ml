type kind =
  | Moved
  | Inserted
  | Removed
  | Attribute
  | Class
  | Text
  | Style
  | Property
  | Created
  | Forced_layout
  | Frame_layout
  | Layout_read
  | Rendered
  | Effect_ran
  | Evaluated
  | Viewed
  | Listed
  | Keyed
  | Projected
  | Refreshed

let kinds =
  [
    Moved; Inserted; Removed; Attribute; Class; Text; Style; Property; Created; Forced_layout; Frame_layout; Layout_read; Rendered;
    Effect_ran; Evaluated; Viewed; Listed; Keyed; Projected; Refreshed;
  ]

let name kind =
  match kind with
  | Moved -> "moves"
  | Inserted -> "insertions"
  | Removed -> "removals"
  | Attribute -> "attributes"
  | Class -> "classes"
  | Text -> "texts"
  | Style -> "styles"
  | Property -> "properties"
  | Created -> "created nodes"
  | Forced_layout -> "forced layouts"
  | Frame_layout -> "frame layouts"
  | Layout_read -> "layout reads"
  | Rendered -> "renders"
  | Effect_ran -> "effects"
  | Evaluated -> "hole evaluations"
  | Viewed -> "view calls"
  | Listed -> "listings"
  | Keyed -> "keys"
  | Projected -> "projections"
  | Refreshed -> "row refreshes"

type t = int Js.Dict.t

let () =
  ([%mel.raw
    {|function () {
  if (globalThis.__ratchet) return;
  var state = { counts: Object.create(null), dirty: false, quiet: 0 };
  globalThis.__ratchet = state;
  var traced = typeof process !== "undefined" && process.env && process.env.RATCHET_TRACE;
  var bump = function (kind, by) {
    if (state.quiet > 0 || by === 0) return;
    state.counts[kind] = (state.counts[kind] || 0) + by;
    if (traced && kind.indexOf(traced) >= 0) console.log("ratchet " + kind + " +" + by + "\n" + new Error().stack.split("\n").slice(3, 9).join("\n"));
  };
  var write = function (kind, by) {
    if (state.quiet > 0 || by === 0) return;
    bump(kind, by);
    state.dirty = true;
  };
  var read = function () {
    if (state.quiet > 0) return;
    bump("layout reads", 1);
    if (state.dirty) { bump("forced layouts", 1); state.dirty = false; }
  };
  state.bump = bump;
  var size = function (node) {
    var total = 1;
    for (var child = node.firstChild; child; child = child.nextSibling) total += size(child);
    return total;
  };
  var placed = function (parent, node) {
    if (!parent.isConnected) return;
    if (typeof node === "string") { write("insertions", 1); return; }
    if (node.nodeType === 11) { write("insertions", node.childNodes.length); return; }
    write(node.isConnected ? "moves" : "insertions", 1);
  };
  var before = function (proto, name, counted) {
    var original = proto[name];
    if (typeof original !== "function") return;
    proto[name] = function () { counted.apply(this, arguments); return original.apply(this, arguments); };
  };
  var after = function (proto, name, counted) {
    var original = proto[name];
    if (typeof original !== "function") return;
    proto[name] = function () { var made = original.apply(this, arguments); counted.call(this, made, arguments); return made; };
  };
  var setter = function (proto, name, counted) {
    var described = Object.getOwnPropertyDescriptor(proto, name);
    if (!described || !described.set) return;
    Object.defineProperty(proto, name, Object.assign({}, described, {
      set: function (value) { counted.call(this, value); described.set.call(this, value); }
    }));
  };
  var getter = function (proto, name, counted) {
    var described = Object.getOwnPropertyDescriptor(proto, name);
    if (!described || !described.get) return;
    Object.defineProperty(proto, name, Object.assign({}, described, {
      get: function () { var value = described.get.call(this); counted.call(this, value); return value; }
    }));
  };
  var connected = function (kind) { return function () { if (this.isConnected) write(kind, 1); }; };
  before(Node.prototype, "insertBefore", function (node) { placed(this, node); });
  before(Node.prototype, "appendChild", function (node) { placed(this, node); });
  before(Element.prototype, "moveBefore", function (node) { placed(this, node); });
  before(Node.prototype, "removeChild", function () { if (this.isConnected) write("removals", 1); });
  before(Node.prototype, "replaceChild", function (node) {
    if (this.isConnected) { write("removals", 1); placed(this, node); }
  });
  [Element.prototype, CharacterData.prototype].forEach(function (proto) {
    before(proto, "remove", function () { if (this.isConnected) write("removals", 1); });
    before(proto, "replaceWith", function () {
      if (this.isConnected) { write("removals", 1); var parent = this.parentNode; Array.prototype.forEach.call(arguments, function (node) { placed(parent, node); }); }
    });
    ["before", "after"].forEach(function (name) {
      before(proto, name, function () { var parent = this.parentNode; if (parent) Array.prototype.forEach.call(arguments, function (node) { placed(parent, node); }); });
    });
  });
  [Element.prototype, DocumentFragment.prototype, Document.prototype].forEach(function (proto) {
    ["append", "prepend"].forEach(function (name) {
      before(proto, name, function () { var parent = this; Array.prototype.forEach.call(arguments, function (node) { placed(parent, node); }); });
    });
    before(proto, "replaceChildren", function () {
      if (!this.isConnected) return;
      write("removals", this.childNodes.length);
      var parent = this; Array.prototype.forEach.call(arguments, function (node) { placed(parent, node); });
    });
  });
  ["setAttribute", "removeAttribute", "toggleAttribute", "setAttributeNS", "removeAttributeNS"].forEach(function (name) {
    before(Element.prototype, name, connected("attributes"));
  });
  setter(Element.prototype, "className", connected("classes"));
  var lists = new WeakMap();
  getter(Element.prototype, "classList", function (list) { lists.set(list, this); });
  ["add", "remove", "toggle", "replace"].forEach(function (name) {
    before(DOMTokenList.prototype, name, function () { var owner = lists.get(this); if (owner && owner.isConnected) write("classes", 1); });
  });
  var replaced = function (value) {
    if (!this.isConnected) return;
    if (this.nodeType !== 1 && this.nodeType !== 11) { write("texts", 1); return; }
    var texts = 0, others = 0;
    for (var child = this.firstChild; child; child = child.nextSibling) { if (child.nodeType === 3) texts++; else others++; }
    write("removals", others);
    if (texts > 0 || (value !== "" && value !== null && value !== undefined)) write("texts", 1);
  };
  setter(Node.prototype, "textContent", replaced);
  setter(Node.prototype, "nodeValue", connected("texts"));
  setter(CharacterData.prototype, "data", connected("texts"));
  setter(Element.prototype, "innerHTML", replaced);
  setter(HTMLElement.prototype, "innerText", replaced);
  var declarations = new WeakMap();
  [HTMLElement.prototype, SVGElement.prototype].forEach(function (proto) {
    getter(proto, "style", function (declaration) { declarations.set(declaration, this); });
    setter(proto, "style", connected("styles"));
  });
  var styled = function () { var owner = declarations.get(this); if (owner && owner.isConnected) write("styles", 1); };
  var styles = CSSStyleDeclaration.prototype;
  before(styles, "setProperty", styled);
  before(styles, "removeProperty", styled);
  Object.getOwnPropertyNames(styles).forEach(function (name) {
    var described = Object.getOwnPropertyDescriptor(styles, name);
    if (described && described.set) setter(styles, name, styled);
  });
  [
    [HTMLInputElement.prototype, ["value", "checked", "defaultValue", "defaultChecked", "indeterminate"]],
    [HTMLTextAreaElement.prototype, ["value", "defaultValue"]],
    [HTMLSelectElement.prototype, ["value", "selectedIndex"]],
    [HTMLOptionElement.prototype, ["selected", "defaultSelected"]],
  ].forEach(function (entry) {
    entry[1].forEach(function (name) { setter(entry[0], name, connected("properties")); });
  });
  ["createElement", "createElementNS", "createTextNode", "createComment"].forEach(function (name) {
    after(Document.prototype, name, function () { bump("created nodes", 1); });
  });
  after(Node.prototype, "cloneNode", function (made, args) { bump("created nodes", args[0] ? size(made) : 1); });
  after(Document.prototype, "importNode", function (made, args) { bump("created nodes", args[1] ? size(made) : 1); });
  ["offsetTop", "offsetLeft", "offsetWidth", "offsetHeight", "offsetParent"].forEach(function (name) {
    getter(HTMLElement.prototype, name, read);
  });
  ["clientTop", "clientLeft", "clientWidth", "clientHeight", "scrollTop", "scrollLeft", "scrollWidth", "scrollHeight"].forEach(function (name) {
    getter(Element.prototype, name, read);
  });
  before(Element.prototype, "getBoundingClientRect", read);
  before(Element.prototype, "getClientRects", read);
  var computed = window.getComputedStyle;
  window.getComputedStyle = function () { read(); return computed.apply(this, arguments); };
}|}]
    : unit -> unit)
    ()

let take : unit -> t =
  [%mel.raw
    {|function () {
  var state = globalThis.__ratchet;
  if (typeof process !== "undefined" && process.env && process.env.RATCHET_TRACE) console.log("ratchet: the step ends");
  if (state.dirty) state.counts["frame layouts"] = (state.counts["frame layouts"] || 0) + 1;
  var taken = state.counts;
  state.counts = Object.create(null);
  state.dirty = false;
  return taken;
}|}]

let count totals kind = Option.value ~default:0 (Js.Dict.get totals (name kind))

let bump kind = ([%mel.raw {|function (kind) { globalThis.__ratchet.bump(kind, 1); }|}] : string -> unit) (name kind)

let seen kind value =
  bump kind;
  value

let unobserved run =
  let quiet : int -> unit = [%mel.raw {|function (by) { globalThis.__ratchet.quiet += by; }|}] in
  quiet 1;
  Fun.protect ~finally:(fun () -> quiet (-1)) run
