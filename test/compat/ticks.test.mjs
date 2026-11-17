// recharts calls an axis's tick function with a props object of its own (test/compat/ticks.mlx): a component passed
// there, or picked between two components with the same labels, must draw the ticks it draws under reason-react on
// React 18, built with -typed on islands, after any clicks.
import fc from "fast-check";
import * as Reason from "../../_build/default/test/compat/react/output/test/compat/react/ticks.mjs";
import * as Island from "../../_build/default/test/compat/island_typed/output/test/compat/island_typed/ticks.mjs";
import { tick } from "./harness.mjs";

const drawn = async (build, clicks) => {
  const root = document.body.appendChild(document.createElement("div"));
  const settle = async () => {
    for (let round = 0; round < 6; round++) await tick();
  };
  const client = build.mount_ticks(root);
  await settle();
  const seen = [];
  for (let click = 0; click <= clicks; click++) {
    seen.push([...root.querySelectorAll(".tick")].map((node) => node.outerHTML).join(""));
    root.querySelector(".double").click();
    await settle();
  }
  build.unmount_ticks(client);
  await settle();
  root.remove();
  return seen;
};

test("components passed to recharts as tick functions draw on islands as on React 18", async () => {
  const first = await drawn(Reason, 1);
  expect(first[0]).toContain('<text class="tick" x="5" y="');
  expect(first[1]).toContain("tick doubled");
  expect(await drawn(Island, 1)).toEqual(first);
  await fc.assert(
    fc.asyncProperty(fc.integer({ min: 0, max: 5 }), async (clicks) => {
      expect(await drawn(Island, clicks)).toEqual(await drawn(Reason, clicks));
    }),
    { numRuns: 6 },
  );
}, 120000);
