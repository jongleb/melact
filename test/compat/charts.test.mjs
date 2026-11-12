// recharts on islands: test/compat/charts.mlx, a dashboard with line and bar charts whose data, series and
// legend labels OCaml state drives, built with reason-react on npm's React 18 and with Melact on islands.
// Both get the same random clicks and must show the same SVG and labels and log the same label renders.
import fc from "fast-check";
import * as Reason from "../../_build/default/test/compat/react/output/test/compat/react/charts.mjs";
import * as Island from "../../_build/default/test/compat/island/output/test/compat/island/charts.mjs";
import { run, tick, enginesKeepTheirOrder } from "./harness.mjs";

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
      await settle(() => (name === "reason-react" ? Reason : Island).unmount_dashboard(client));
      root.remove();
      layer.remove();
    },
  };
};

const app = (at) => () => (at.lib.name === "reason-react" ? Reason : Island).mount_dashboard(at.root, (line) => at.log.push(line));
const perform = (at, button) => at.root.querySelector("." + button).click();
const sides = () => [side("reason-react"), { ...side("islands"), relax: enginesKeepTheirOrder }];
const button = fc.constantFrom("add", "drop", "raise", "kind", "second", "suffix");

test("a recharts dashboard driven by OCaml state draws on islands as on React 18", async () => {
  await run(sides(), app, ["add", "raise", "second", "kind", "suffix", "second", "kind", "drop"], perform);
  await fc.assert(
    fc.asyncProperty(fc.array(button, { minLength: 1, maxLength: 14 }), async (actions) => {
      await run(sides(), app, actions, perform);
    }),
    { numRuns: 40 },
  );
}, 240000);
