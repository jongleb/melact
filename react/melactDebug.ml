external console_warn : string -> unit = "warn" [@@mel.scope "console"]

let watch : (string -> unit) -> unit =
  [%mel.raw
    {|function (reading) {
        var mark = function (fn) { fn.__melactWatched = true; return fn; };
        var getter = function (proto, name) {
          var described = Object.getOwnPropertyDescriptor(proto, name);
          if (!described || !described.get || described.get.__melactWatched) return;
          var get = described.get;
          Object.defineProperty(proto, name, Object.assign({}, described, {
            get: mark(function () { reading(name); return get.call(this); })
          }));
        };
        var method = function (owner, name, self) {
          var fn = owner[name];
          if (typeof fn !== "function" || fn.__melactWatched) return;
          owner[name] = mark(function () { reading(name); return fn.apply(self === undefined ? this : self, arguments); });
        };
        ["offsetTop", "offsetLeft", "offsetWidth", "offsetHeight", "offsetParent", "innerText"].forEach(function (name) { getter(HTMLElement.prototype, name); });
        ["clientTop", "clientLeft", "clientWidth", "clientHeight", "scrollTop", "scrollLeft", "scrollWidth", "scrollHeight"].forEach(function (name) { getter(Element.prototype, name); });
        ["getBoundingClientRect", "getClientRects"].forEach(function (name) { method(Element.prototype, name); });
        method(window, "getComputedStyle", window);
      }|}]

let warnLayoutReadsInRender () =
  let warned = Hashtbl.create 16 in
  watch (fun property ->
      Option.iter
        (fun component ->
          let seen = component ^ " " ^ property in
          match Hashtbl.mem warned seen with
          | true -> ()
          | false ->
              Hashtbl.add warned seen ();
              console_warn
                ("melact: " ^ component ^ " reads " ^ property
               ^ " while it renders; under Melact each such read forces a layout, since the DOM is written component by component. Read it in useLayoutEffect or a ref callback, which run after the whole write."))
        (Melact_runtime.Instance.writing_component ()))
