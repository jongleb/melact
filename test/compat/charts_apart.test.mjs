// recharts bound in another file: test/compat/charts_apart.mlx draws charts whose components
// test/compat/recharts.mlx binds. Built with reason-react on npm's React 18 and with Melact on islands, both
// get the same random clicks and must show the same SVG; on islands each chart and its children are one
// React tree, so the page holds one island, never one per child, and React warns of no child without a key
// where reason-react passes the children one by one.
import fc from "fast-check";
import * as Reason from "../../_build/default/test/compat/react/output/test/compat/react/charts_apart.mjs";
import * as Island from "../../_build/default/test/compat/island/output/test/compat/island/charts_apart.mjs";
import { run, tick, enginesKeepTheirOrder } from "./harness.mjs";

const side = (name) => {
  const root = document.body.appendChild(document.createElement("div"));
  const layer = document.body.appendChild(document.createElement("div"));
  let client;
  const settle = async (act) => {
    act?.();
    for (let round = 0; round < 6; round++) await tick();
    const islands = root.querySelectorAll("melact-island").length;
    if (name === "islands" && islands !== 1) throw new Error(`the chart and its children are ${islands} islands, not one`);
  };
  return {
    lib: { name },
    root,
    layer,
    log: [],
    settle,
    async render(begin) {
      await settle(() => {
        client = begin();
      });
    },
    async unmount() {
      (name === "reason-react" ? Reason : Island).unmount_dashboard(client);
      for (let round = 0; round < 6; round++) await tick();
      root.remove();
      layer.remove();
    },
  };
};

const app = (at) => () => (at.lib.name === "reason-react" ? Reason : Island).mount_dashboard(at.root);
const perform = (at, button) => at.root.querySelector("." + button).click();
const sides = () => [side("reason-react"), { ...side("islands"), relax: enginesKeepTheirOrder }];
const button = fc.constantFrom("add", "raise", "kind", "second", "suffix");

test("recharts bound in another file draws each chart as one React tree, as on React 18", async () => {
  const errors = vi.spyOn(console, "error");
  await run(sides(), app, ["second", "add", "second", "kind", "suffix", "kind", "raise"], perform);
  await fc.assert(
    fc.asyncProperty(fc.array(button, { minLength: 1, maxLength: 12 }), async (actions) => {
      await run(sides(), app, actions, perform);
    }),
    { numRuns: 30 },
  );
  expect(errors.mock.calls.filter((call) => String(call[0]).includes('unique "key"'))).toEqual([]);
  errors.mockRestore();
}, 240000);
