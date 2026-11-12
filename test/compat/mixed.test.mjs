// The mixed laws: test/compat/mixed.mlx, OCaml components with JavaScript library components inside
// and around them, built with reason-react on npm's React 18 and with Melact on melact.compat.
// Both builds get the same random tree and the same random actions and must show, order and log
// the same: the DOM (L1), the OCaml callbacks (L2), handlers across layers with capture and
// stopPropagation (L3), context values across layers (L4), row state under recycling (L5) and the
// order of layout and passive effects with cleanups (L6).
import fc from "fast-check";
import * as Reason from "../../_build/default/test/compat/react/output/test/compat/react/mixed.mjs";
import * as Melact from "../../_build/default/test/compat/melact/output/test/compat/melact/mixed.mjs";
import * as Island from "../../_build/default/test/compat/island/output/test/compat/island/mixed.mjs";
import { run, fire, nativeValue, tick, enginesKeepTheirOrder, portalsInAnyOrder } from "./harness.mjs";

const side = (name, build) => {
  const root = document.body.appendChild(document.createElement("div"));
  const layer = document.body.appendChild(document.createElement("div"));
  const log = [];
  let client;
  const settle = async (act) => {
    act?.();
    for (let round = 0; round < 6; round++) await tick();
  };
  return {
    lib: { name },
    build,
    root,
    layer,
    log,
    settle,
    async render(begin) {
      await settle(() => {
        client = begin();
      });
    },
    async unmount() {
      await settle(() => build.unmount(client));
      root.remove();
      layer.remove();
    },
  };
};

const engines = [
  ["melact.compat", Melact, {}],
  ["islands of npm's React", Island, { relax: enginesKeepTheirOrder, relaxLayer: portalsInAnyOrder }],
];
// The layer's targets go by class and title, not by place: the islands engine may order portals there differently
// (portalsInAnyOrder), and both sides must still click the same element.
const everywhere = (at, selector) => {
  const named = (node) => `${node.className}|${node.title}`;
  const layered = Array.from(at.layer.querySelectorAll(selector)).sort((a, b) => named(a).localeCompare(named(b)));
  return [...at.root.querySelectorAll(selector), ...layered];
};

const layered = (tape) => (at) => () => at.build.mount_layers(at.root, at.layer, tape, (line) => at.log.push(line));

const layerAction = fc.oneof(
  fc.tuple(fc.constant("click"), fc.nat(40)),
  fc.tuple(fc.constant("button"), fc.constantFrom("rerender", "stop")),
);

const performLayer = (at, [kind, argument]) => {
  if (kind === "button") return at.root.querySelector("." + argument).click();
  const targets = everywhere(at, ".mel, .js, .theme, .tally, .bump");
  if (targets.length) targets[argument % targets.length].click();
};

for (const [engine, build, relaxations] of engines) {
  const sides = () => [side("reason-react", Reason), { ...side(engine, build), ...relaxations }];
  test(`L1 L3 L4 L6: random layers of OCaml and JavaScript components on ${engine} agree with React 18`, async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(fc.nat(1000), { minLength: 1, maxLength: 30 }),
        fc.array(layerAction, { minLength: 1, maxLength: 12 }),
        async (tape, actions) => {
          await run(sides(), layered(tape), actions, performLayer);
        },
      ),
      { numRuns: 60 },
    );
  }, 240000);
}

const widgets = (at) => () => at.build.mount_widgets(at.root, at.layer, (line) => at.log.push(line));

const performWidget = (at, [kind, argument]) => {
  const input = at.root.querySelector("input");
  switch (kind) {
    case "button":
      return at.root.querySelector("." + argument).click();
    case "press":
      return fire(at.root.querySelector("[class*='-control']"), "mousedown", { button: 0 });
    case "key":
      return fire(document.activeElement && document.activeElement !== document.body ? document.activeElement : input, "keydown", { key: argument });
    case "type":
      nativeValue(input, input.value + argument);
      return fire(input, "input");
    case "focus":
      return input.focus();
    case "option": {
      const found = everywhere(at, "[id*='-option-']");
      if (found.length) found[argument % found.length].click();
      return;
    }
    case "trigger":
      return at.root.querySelector(".trigger").click();
    case "inside": {
      const found = everywhere(at, ".content .bump, .content .mel, .close");
      if (found.length) found[argument % found.length].click();
      return;
    }
    case "scroll": {
      const list = at.root.querySelector(".frame")?.parentElement;
      if (!list) return;
      list.scrollTop = argument;
      return fire(list, "scroll", { bubbles: false });
    }
    case "row": {
      const rows = at.root.querySelectorAll(".row");
      if (rows.length) rows[argument % rows.length].click();
      return;
    }
  }
};

const widgetAction = fc.oneof(
  fc.tuple(fc.constant("button"), fc.constantFrom("relabel", "choose")),
  fc.tuple(fc.constant("press"), fc.constant(0)),
  fc.tuple(fc.constant("key"), fc.constantFrom("ArrowDown", "Enter", "Escape", "Backspace")),
  fc.tuple(fc.constant("type"), fc.constantFrom("a", "e")),
  fc.tuple(fc.constant("focus"), fc.constant(0)),
  fc.tuple(fc.constant("option"), fc.nat(3)),
  fc.tuple(fc.constant("trigger"), fc.constant(0)),
  fc.tuple(fc.constant("inside"), fc.nat(3)),
  fc.tuple(fc.constant("scroll"), fc.nat(500)),
  fc.tuple(fc.constant("row"), fc.nat(6)),
);

const scripted = [
  ["row", 1],
  ["scroll", 120],
  ["row", 0],
  ["scroll", 0],
  ["button", "relabel"],
  ["focus", 0],
  ["press", 0],
  ["key", "ArrowDown"],
  ["key", "Enter"],
  ["button", "choose"],
  ["trigger", 0],
  ["inside", 0],
  ["inside", 1],
  ["key", "Escape"],
];

for (const [engine, build, relaxations] of engines) {
  const sides = () => [side("reason-react", Reason), { ...side(engine, build), ...relaxations }];
  test(`L1 L2 L5: react-select, a Radix popover with asChild and react-window with OCaml rows on ${engine} agree with React 18`, async () => {
    await run(sides(), widgets, scripted, performWidget);
    await fc.assert(
      fc.asyncProperty(fc.array(widgetAction, { minLength: 1, maxLength: 16 }), async (actions) => {
        await run(sides(), widgets, actions, performWidget);
      }),
      { numRuns: 40 },
    );
  }, 240000);
}
