// @radix-ui/react-popover (context across its parts, a portal, capture-phase handlers, asChild's
// cloneElement, a focus scope, a dismissable layer, floating-ui's layout effects) on npm's React 18
// and on melact.compat.
import fc from "fast-check";
import { real } from "./libraries.mjs";
import { shim } from "./env/libraries.mjs";
import { stage, run, fire } from "./harness.mjs";

const app = (side) => {
  const { React, Popover } = side.lib;
  const h = React.createElement;
  const log = side.log;
  const note = (name) => (event) => log.push([name, event && event.type]);
  function Panel() {
    const [controlled, setControlled] = React.useState(false);
    const [open, setOpen] = React.useState(false);
    const [modal, setModal] = React.useState(false);
    const [text, setText] = React.useState("");
    const parts = [
      h(Popover.Trigger, { asChild: true, key: "trigger" }, h("button", { className: "trigger", onClick: note("trigger click") }, "open")),
      h(Popover.Anchor, { key: "anchor" }, h("span", { className: "anchor" }, "anchor")),
      h(
        Popover.Portal,
        { container: side.layer, key: "portal" },
        h(
          Popover.Content,
          {
            className: "content",
            sideOffset: 4,
            onOpenAutoFocus: note("open focus"),
            onCloseAutoFocus: note("close focus"),
            onEscapeKeyDown: note("escape"),
            onPointerDownOutside: note("pointer outside"),
            onFocusOutside: note("focus outside"),
            onInteractOutside: note("interact outside"),
          },
          h("input", { className: "field", value: text, onChange: (event) => setText(event.target.value) }),
          h("span", { className: "echo" }, text),
          h(Popover.Close, { className: "close" }, "x"),
          h(Popover.Arrow, { width: 10, height: 5 }),
        ),
      ),
    ];
    const rootProps = controlled
      ? { open, modal, onOpenChange: (next) => (log.push(["open change", next]), setOpen(next)) }
      : { modal, onOpenChange: (next) => log.push(["open change", next]) };
    return h(
      "div",
      { className: "panel" },
      h("button", { className: "control", onClick: () => setControlled((on) => !on) }, controlled ? "controlled" : "free"),
      h("button", { className: "toggle", onClick: () => setOpen((on) => !on) }, "toggle"),
      h("button", { className: "modal", onClick: () => setModal((on) => !on) }, modal ? "modal" : "modeless"),
      h("button", { className: "outside" }, "outside"),
      h(Popover.Root, { ...rootProps, key: controlled ? "c" : "u" }, ...parts),
    );
  }
  return h(Panel);
};

const content = (side) => side.layer.querySelector(".content");

const perform = (side, action) => {
  const [kind, argument] = action;
  switch (kind) {
    case "button":
      return side.root.querySelector("." + argument).click();
    case "trigger":
      return side.root.querySelector(".trigger").click();
    case "escape": {
      const target = document.activeElement && document.activeElement !== document.body ? document.activeElement : side.root;
      return fire(target, "keydown", { key: "Escape" });
    }
    case "outside": {
      const outside = side.root.querySelector(".outside");
      fire(outside, "pointerdown", { button: 0 });
      fire(outside, "mousedown", { button: 0 });
      outside.focus();
      fire(outside, "pointerup", { button: 0 });
      return outside.click();
    }
    case "close": {
      const close = side.layer.querySelector(".close");
      if (close) close.click();
      return;
    }
    case "type": {
      const field = side.layer.querySelector(".field");
      if (!field) return;
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(field, field.value + argument);
      return fire(field, "input");
    }
    case "inside": {
      const at = content(side);
      if (!at) return;
      fire(at, "pointerdown", { button: 0 });
      return fire(at, "pointerup", { button: 0 });
    }
    case "tab": {
      const target = document.activeElement || side.root;
      return fire(target, "keydown", { key: "Tab", shiftKey: argument === 1 });
    }
  }
};

const action = fc.oneof(
  fc.tuple(fc.constant("button"), fc.constantFrom("control", "toggle", "modal")),
  fc.tuple(fc.constant("trigger"), fc.constant(0)),
  fc.tuple(fc.constant("escape"), fc.constant(0)),
  fc.tuple(fc.constant("outside"), fc.constant(0)),
  fc.tuple(fc.constant("close"), fc.constant(0)),
  fc.tuple(fc.constant("type"), fc.constantFrom("a", "b")),
  fc.tuple(fc.constant("inside"), fc.constant(0)),
  fc.tuple(fc.constant("tab"), fc.nat(1)),
);

const scripted = [
  ["trigger", 0],
  ["type", "a"],
  ["inside", 0],
  ["escape", 0],
  ["trigger", 0],
  ["outside", 0],
  ["button", "control"],
  ["button", "toggle"],
  ["type", "b"],
  ["close", 0],
  ["button", "modal"],
  ["trigger", 0],
  ["tab", 0],
  ["escape", 0],
];

test("radix popover: a scripted session gives React's DOM, focus and callbacks", async () => {
  await run([stage(real), stage(shim)], app, scripted, perform);
});

test("radix popover: random sessions give React's DOM, focus and callbacks", async () => {
  await fc.assert(
    fc.asyncProperty(fc.array(action, { minLength: 1, maxLength: 16 }), async (actions) => {
      await run([stage(real), stage(shim)], app, actions, perform);
    }),
    { numRuns: 40 },
  );
}, 180000);
