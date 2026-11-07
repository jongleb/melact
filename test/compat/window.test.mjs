// react-window 2 (useSyncExternalStore, layout effects, a row component prop, rows recycled on
// scroll) on npm's React 18 and on melact.compat. Rows keep state, so recycling shows.
import fc from "fast-check";
import { real } from "./libraries.mjs";
import { shim } from "./env/libraries.mjs";
import { stage, run, fire } from "./harness.mjs";

const app = (side) => {
  const { React, List } = side.lib;
  const h = React.createElement;
  const log = side.log;
  function Row({ index, style, ariaAttributes, label }) {
    const [clicks, setClicks] = React.useState(0);
    React.useEffect(() => {
      log.push(["row mounted", index]);
      return () => log.push(["row unmounted", index]);
    }, []);
    return h(
      "div",
      { style, ...ariaAttributes, className: "row", onClick: () => setClicks((n) => n + 1) },
      `${label} ${index} clicked ${clicks}`,
    );
  }
  function Feed() {
    const [count, setCount] = React.useState(40);
    const [label, setLabel] = React.useState("row");
    const [height, setHeight] = React.useState(20);
    const listRef = React.useRef(null);
    return h(
      "div",
      { className: "feed" },
      h("button", { className: "more", onClick: () => setCount((n) => n + 13) }, "more"),
      h("button", { className: "less", onClick: () => setCount((n) => Math.max(0, n - 17)) }, "less"),
      h("button", { className: "label", onClick: () => setLabel((text) => (text === "row" ? "item" : "row")) }, "label"),
      h("button", { className: "taller", onClick: () => setHeight((n) => (n === 20 ? 30 : 20)) }, "taller"),
      h("button", { className: "jump", onClick: () => listRef.current && count > 0 && listRef.current.scrollToRow({ index: Math.min(25, count - 1) }) }, "jump"),
      h(List, {
        listRef,
        rowComponent: Row,
        rowCount: count,
        rowHeight: height,
        rowProps: { label },
        defaultHeight: 100,
        overscanCount: 2,
        style: { height: 100 },
        onRowsRendered: (visible, all) => log.push(["rows", visible.startIndex, visible.stopIndex, all.startIndex, all.stopIndex]),
      }),
    );
  }
  return h(Feed);
};

const scroller = (side) => side.root.querySelector(".feed > div[role], .feed > div:last-child");

const perform = (side, action) => {
  const [kind, argument] = action;
  switch (kind) {
    case "button":
      return side.root.querySelector("." + argument).click();
    case "scroll": {
      const list = scroller(side);
      list.scrollTop = argument;
      return fire(list, "scroll", { bubbles: false });
    }
    case "click": {
      const rows = side.root.querySelectorAll(".row");
      if (rows.length) rows[argument % rows.length].click();
      return;
    }
  }
};

const action = fc.oneof(
  fc.tuple(fc.constant("button"), fc.constantFrom("more", "less", "label", "taller", "jump")),
  fc.tuple(fc.constant("scroll"), fc.nat(900)),
  fc.tuple(fc.constant("click"), fc.nat(9)),
);

const scripted = [
  ["click", 1],
  ["scroll", 100],
  ["click", 2],
  ["scroll", 0],
  ["button", "label"],
  ["scroll", 300],
  ["button", "taller"],
  ["button", "less"],
  ["button", "less"],
  ["button", "more"],
  ["button", "jump"],
  ["click", 0],
];

test("react-window: a scripted session gives React's DOM and callbacks", async () => {
  await run([stage(real), stage(shim)], app, scripted, perform);
});

test("react-window: random sessions give React's DOM, row state and callbacks", async () => {
  await fc.assert(
    fc.asyncProperty(fc.array(action, { minLength: 1, maxLength: 16 }), async (actions) => {
      await run([stage(real), stage(shim)], app, actions, perform);
    }),
    { numRuns: 40 },
  );
}, 180000);
