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
  | Walked
  | Timer
  | Frame
  | Task
  | Microtask
  | Reaction
  | Listened
  | Unlistened
  | Recorded
  | Kept_node
  | Kept_listener
  | Kept_timer
  | Kept_global
  | Sent
  | Jobs_moved
  | Expando

let kinds =
  [
    Moved; Inserted; Removed; Attribute; Class; Text; Style; Property; Created; Forced_layout; Frame_layout; Layout_read; Rendered;
    Effect_ran; Evaluated; Viewed; Listed; Keyed; Projected; Refreshed; Walked; Timer; Frame; Task; Microtask; Reaction; Listened;
    Unlistened; Recorded; Kept_node; Kept_listener; Kept_timer; Kept_global; Sent; Jobs_moved; Expando;
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
  | Walked -> "nodes walked"
  | Timer -> "timers"
  | Frame -> "animation frames"
  | Task -> "tasks"
  | Microtask -> "microtasks"
  | Reaction -> "promise reactions"
  | Listened -> "listeners added"
  | Unlistened -> "listeners removed"
  | Recorded -> "mutation records"
  | Kept_node -> "nodes kept"
  | Kept_listener -> "listeners kept"
  | Kept_timer -> "timers kept"
  | Kept_global -> "globals kept"
  | Sent -> "bytes served"
  | Jobs_moved -> "queued jobs moved"
  | Expando -> "node expandos"

type t = int Js.Dict.t

let () =
  ([%mel.raw
    {|function () {
  if (globalThis.__ratchet) return;
  var state = { counts: Object.create(null), dirty: false, layout: null, made: null, generation: 0 };
  globalThis.__ratchet = state;
  var hushed = 0;
  var observer = null;
  var recorded = function (records) {
    bump("mutation records", records.length);
    if (traced === "records") records.forEach(function (record) { console.log("record " + record.type + " " + (record.attributeName || "") + " " + record.target.nodeName + " +" + record.addedNodes.length + " -" + Array.prototype.map.call(record.removedNodes, function (node) { return node.nodeName + (node.nodeType === 3 ? JSON.stringify(node.data) : ""); }).join(",")); });
  };
  Object.defineProperty(state, "quiet", {
    get: function () { return hushed; },
    set: function (level) {
      if (observer && hushed === 0 && level > 0) recorded(observer.takeRecords());
      if (observer && hushed > 0 && level === 0) observer.takeRecords();
      hushed = level;
    },
  });
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
  ["nextNode", "previousNode", "firstChild", "lastChild", "nextSibling", "previousSibling", "parentNode"].forEach(function (name) {
    before(TreeWalker.prototype, name, function () { bump("nodes walked", 1); });
  });
  ["nextNode", "previousNode"].forEach(function (name) {
    before(NodeIterator.prototype, name, function () { bump("nodes walked", 1); });
  });
  var selecting = 0;
  before(Node.prototype, "compareDocumentPosition", function () { if (selecting === 0) bump("nodes walked", 1); });
  before(Node.prototype, "contains", function () { if (selecting === 0) bump("nodes walked", 1); });
  [Element.prototype, Document.prototype, DocumentFragment.prototype].forEach(function (proto) {
    ["querySelector", "querySelectorAll", "matches", "closest"].forEach(function (name) {
      var original = proto[name];
      if (typeof original !== "function") return;
      proto[name] = function () {
        selecting++;
        try { return original.apply(this, arguments); } finally { selecting--; }
      };
    });
  });
  var computed = window.getComputedStyle;
  window.getComputedStyle = function () { read(); return computed.apply(this, arguments); };
  var remembered = function (node) { if (state.made && state.quiet === 0) state.made.push(new WeakRef(node)); };
  ["createElement", "createElementNS", "createTextNode", "createComment"].forEach(function (name) {
    after(Document.prototype, name, remembered);
  });
  after(Node.prototype, "cloneNode", remembered);
  after(Document.prototype, "importNode", remembered);
  var idle = function (callback) {
    return state.clock.setTimeout(function () { callback({ didTimeout: false, timeRemaining: function () { return 0; } }); }, 1);
  };
  state.clock = {
    setTimeout: window.setTimeout, clearTimeout: window.clearTimeout,
    setInterval: window.setInterval, clearInterval: window.clearInterval,
    setImmediate: globalThis.setImmediate, clearImmediate: globalThis.clearImmediate,
    requestAnimationFrame: window.requestAnimationFrame || function (callback) { return state.clock.setTimeout(function () { callback(performance.now()); }, 16); },
    cancelAnimationFrame: window.cancelAnimationFrame || function (handle) { state.clock.clearTimeout(handle); },
    requestIdleCallback: window.requestIdleCallback || idle,
    cancelIdleCallback: window.cancelIdleCallback || function (handle) { state.clock.clearTimeout(handle); },
    queueMicrotask: window.queueMicrotask,
  };
  var scheduled = {
    setTimeout: "timers", setInterval: "timers", requestIdleCallback: "timers", requestAnimationFrame: "animation frames",
    setImmediate: "tasks", queueMicrotask: "microtasks",
    clearTimeout: null, clearInterval: null, clearImmediate: null, cancelAnimationFrame: null, cancelIdleCallback: null,
  };
  Object.keys(scheduled).forEach(function (name) {
    var kind = scheduled[name];
    window[name] = function () { if (kind) bump(kind, 1); return state.clock[name].apply(window, arguments); };
  });
  if (typeof MessagePort !== "undefined") before(MessagePort.prototype, "postMessage", function () { bump("tasks", 1); });
  before(Promise.prototype, "then", function () { bump("promise reactions", 1); });
  var registered = new WeakMap();
  state.listened = [];
  var listening = function (target, type, options) {
    var capture = typeof options === "boolean" ? options : !!(options && options.capture);
    var listeners = registered.get(target);
    if (!listeners) {
      listeners = new Map();
      registered.set(target, listeners);
      state.listened.push(new WeakRef(target));
    }
    var key = type + (capture ? " capture" : "");
    if (!listeners.has(key)) listeners.set(key, new Map());
    return listeners.get(key);
  };
  var added = EventTarget.prototype.addEventListener;
  var removed = EventTarget.prototype.removeEventListener;
  EventTarget.prototype.addEventListener = function (type, listener, options) {
    if (listener && state.quiet === 0) {
      var listeners = listening(this, type, options);
      if (!listeners.has(listener)) { listeners.set(listener, state.made !== null ? state.generation : 0); bump("listeners added", 1); }
    }
    return added.apply(this, arguments);
  };
  EventTarget.prototype.removeEventListener = function (type, listener, options) {
    if (listener && state.quiet === 0) {
      var listeners = listening(this, type, options);
      if (listeners.has(listener)) { listeners.delete(listener); bump("listeners removed", 1); }
    }
    return removed.apply(this, arguments);
  };
  state.listening = function () {
    var count = 0;
    state.listened.forEach(function (held) {
      var target = held.deref();
      if (target) registered.get(target).forEach(function (listeners) { listeners.forEach(function (during) { if (during > 0 && during === state.generation) count++; }); });
    });
    return count;
  };
  [["offsetTop", "offsetLeft", "offsetWidth", "offsetHeight"], ["clientTop", "clientLeft", "clientWidth", "clientHeight", "scrollWidth", "scrollHeight", "scrollTop", "scrollLeft"]].forEach(function (names, at) {
    var proto = at === 0 ? HTMLElement.prototype : Element.prototype;
    names.forEach(function (name) {
      var described = Object.getOwnPropertyDescriptor(proto, name);
      if (!described || !described.get) return;
      Object.defineProperty(proto, name, Object.assign({}, described, {
        get: function () { return state.layout ? (read(), state.layout.get(this, name)) : described.get.call(this); },
        set: described.set && function (value) { if (state.layout) state.layout.set(this, name, value); else described.set.call(this, value); },
      }));
    });
  });
  var bounded = Element.prototype.getBoundingClientRect;
  Element.prototype.getBoundingClientRect = function () { return state.layout ? (read(), state.layout.rect(this)) : bounded.call(this); };
  observer = new MutationObserver(recorded);
  observer.observe(document, { subtree: true, childList: true, attributes: true, characterData: true });
  state.take = function () {
    if (traced) console.log("ratchet: the step ends");
    if (hushed === 0) recorded(observer.takeRecords()); else observer.takeRecords();
    if (state.dirty) state.counts["frame layouts"] = (state.counts["frame layouts"] || 0) + 1;
    var expandos = 0, stack = document.documentElement ? [document.documentElement] : [];
    while (stack.length > 0) {
      var node = stack.pop();
      expandos += Object.keys(node).length;
      for (var child = node.firstChild; child; child = child.nextSibling) stack.push(child);
    }
    var grown = expandos - (state.expandos || 0);
    state.expandos = expandos;
    if (grown > 0) state.counts["node expandos"] = (state.counts["node expandos"] || 0) + grown;
    var taken = state.counts;
    state.counts = Object.create(null);
    state.dirty = false;
    return taken;
  };
}|}]
    : unit -> unit)
    ()

let take : unit -> t = [%mel.raw {|function () { return globalThis.__ratchet.take(); }|}]

let count totals kind = Option.value ~default:0 (Js.Dict.get totals (name kind))

let bump kind = ([%mel.raw {|function (kind) { globalThis.__ratchet.bump(kind, 1); }|}] : string -> unit) (name kind)

let seen kind value =
  bump kind;
  value

let unobserved run =
  let quiet : int -> unit = [%mel.raw {|function (by) { globalThis.__ratchet.quiet += by; }|}] in
  quiet 1;
  Fun.protect ~finally:(fun () -> quiet (-1)) run
