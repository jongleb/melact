// Melact's React.lazy_ and React.preloadLazy, which reason-react has no counterpart of: a lazy component suspends
// to its Suspense boundary until its code arrives, loads it once however often it renders or is preloaded, keeps
// its state across renders of its parent, and once preloaded renders at once, without its fallback.
import * as React from "../../_build/default/test/team/melact/output/node_modules/melact/react.mjs";
import * as ReactDOMClient from "../../_build/default/test/team/melact/output/node_modules/melact/reactDOMClient.mjs";
import { tick } from "../compat/harness.mjs";

const settle = async (root) => {
  for (let round = 0; round < 4 || (root.textContent === "loading" && round < 2000); round++) await tick();
};

const counted = () => {
  const loads = { count: 0 };
  const shown = (props) => React.string(props.text);
  const component = React.lazy_(() => {
    loads.count++;
    return Promise.resolve({ default: shown });
  });
  return { loads, component };
};

const page = (component, text) =>
  React.Suspense.make({ children: React.createElement(component, { text }), fallback: React.string("loading") });

test("a lazy component shows its fallback until its code arrives, then loads it once across renders", async () => {
  const { loads, component } = counted();
  const root = document.body.appendChild(document.createElement("div"));
  const mounted = ReactDOMClient.createRoot(root);
  ReactDOMClient.render(mounted, page(component, "a"));
  await React.act(() => {});
  expect(root.textContent).toBe("loading");
  await settle(root);
  expect(root.textContent).toBe("a");
  for (const text of ["b", "c"]) {
    ReactDOMClient.render(mounted, page(component, text));
    await settle(root);
  }
  expect([root.textContent, loads.count]).toEqual(["c", 1]);
  root.remove();
});

test("a preloaded lazy component renders without its fallback, and preloading loads once", async () => {
  const { loads, component } = counted();
  await Promise.all([React.preloadLazy(component), React.preloadLazy(component)]);
  await React.preloadLazy((props) => React.string(props.text));
  const root = document.body.appendChild(document.createElement("div"));
  ReactDOMClient.render(ReactDOMClient.createRoot(root), page(component, "now"));
  await React.act(() => {});
  expect([root.textContent, loads.count]).toEqual(["now", 1]);
  root.remove();
});
