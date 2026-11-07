// react-select 5 (a class component with getDerivedStateFromProps, emotion styles, a menu portal,
// keyboard handling and a controlled value) on npm's React 18 and on melact.compat.
import fc from "fast-check";
import { real } from "./libraries.mjs";
import { shim } from "./env/libraries.mjs";
import { stage, run, fire, nativeValue } from "./harness.mjs";

const fruits = ["Apple", "Banana", "Cherry", "Date", "Elder", "Fig"].map((label) => ({ value: label.toLowerCase(), label }));

const app = (side) => {
  const { React, Select } = side.lib;
  const h = React.createElement;
  const log = side.log;
  function Form() {
    const [value, setValue] = React.useState(null);
    const [disabled, setDisabled] = React.useState(false);
    const [count, setCount] = React.useState(4);
    const [portal, setPortal] = React.useState(false);
    React.useEffect(() => {
      log.push(["value", value && value.value]);
    }, [value]);
    return h(
      "div",
      { className: "form" },
      h("button", { className: "pick", onClick: () => setValue(fruits[(fruits.indexOf(value) + 2) % count] ?? null) }, "pick"),
      h("button", { className: "clear-outside", onClick: () => setValue(null) }, "none"),
      h("button", { className: "disable", onClick: () => setDisabled((on) => !on) }, "disable"),
      h("button", { className: "more", onClick: () => setCount((n) => (n % fruits.length) + 1) }, "more"),
      h("button", { className: "portal", onClick: () => setPortal((on) => !on) }, "portal"),
      h(Select, {
        instanceId: "fruit",
        options: fruits.slice(0, count),
        value,
        isDisabled: disabled,
        isClearable: true,
        menuPortalTarget: portal ? side.layer : null,
        onChange: (next, meta) => {
          log.push(["change", next && next.value, meta.action]);
          setValue(next);
        },
        onInputChange: (text, meta) => {
          log.push(["input", text, meta.action]);
        },
        onMenuOpen: () => log.push(["open"]),
        onMenuClose: () => log.push(["close"]),
        onFocus: () => log.push(["focus"]),
        onBlur: () => log.push(["blur"]),
        onKeyDown: (event) => log.push(["key", event.key, event.defaultPrevented]),
      }),
    );
  }
  return h(Form);
};

const input = (side) => side.root.querySelector("input");
const scope = (side) => [side.root, side.layer];
const options = (side) => scope(side).flatMap((at) => Array.from(at.querySelectorAll("[id*='-option-']")));

const perform = (side, action) => {
  const [kind, argument] = action;
  switch (kind) {
    case "button":
      return side.root.querySelector("." + argument).click();
    case "press":
      return fire(side.root.querySelector("[class*='-control']"), "mousedown", { button: 0 });
    case "key":
      return fire(input(side), "keydown", { key: argument });
    case "type": {
      const field = input(side);
      nativeValue(field, field.value + argument);
      return fire(field, "input");
    }
    case "erase": {
      const field = input(side);
      nativeValue(field, field.value.slice(0, -1));
      return fire(field, "input");
    }
    case "focus":
      return input(side).focus();
    case "blur":
      return input(side).blur();
    case "hover": {
      const found = options(side);
      if (found.length) fire(found[argument % found.length], "mouseover");
      return;
    }
    case "choose": {
      const found = options(side);
      if (found.length) found[argument % found.length].click();
      return;
    }
    case "indicator": {
      const found = side.root.querySelectorAll("[class*='indicatorContainer']");
      if (found.length) fire(found[argument % found.length], "mousedown", { button: 0 });
      return;
    }
  }
};

const action = fc.oneof(
  fc.tuple(fc.constant("button"), fc.constantFrom("pick", "clear-outside", "disable", "more", "portal")),
  fc.tuple(fc.constant("press"), fc.constant(0)),
  fc.tuple(fc.constant("key"), fc.constantFrom("ArrowDown", "ArrowUp", "Enter", "Escape", "Tab", "Backspace", "Home", "End", " ")),
  fc.tuple(fc.constant("type"), fc.constantFrom("a", "e", "r", "x")),
  fc.tuple(fc.constant("erase"), fc.constant(0)),
  fc.tuple(fc.constant("focus"), fc.constant(0)),
  fc.tuple(fc.constant("blur"), fc.constant(0)),
  fc.tuple(fc.constant("hover"), fc.nat(5)),
  fc.tuple(fc.constant("choose"), fc.nat(5)),
  fc.tuple(fc.constant("indicator"), fc.nat(2)),
);

const scripted = [
  ["focus", 0],
  ["press", 0],
  ["hover", 1],
  ["key", "ArrowDown"],
  ["key", "Enter"],
  ["type", "a"],
  ["type", "e"],
  ["key", "ArrowDown"],
  ["key", "Enter"],
  ["button", "portal"],
  ["press", 0],
  ["choose", 0],
  ["indicator", 0],
  ["button", "pick"],
  ["button", "disable"],
  ["button", "disable"],
  ["key", "Escape"],
  ["blur", 0],
];

test("react-select: a scripted session gives React's DOM, focus and callbacks", async () => {
  await run([stage(real), stage(shim)], app, scripted, perform);
});

test("react-select: random sessions give React's DOM, focus and callbacks", async () => {
  await fc.assert(
    fc.asyncProperty(fc.array(action, { minLength: 1, maxLength: 24 }), async (actions) => {
      await run([stage(real), stage(shim)], app, actions, perform);
    }),
    { numRuns: 60 },
  );
}, 120000);
