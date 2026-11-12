// Law 1 of islands, render economy: a page of twenty islands renders in React exactly the islands whose
// props changed; Melact content in their slots changes without React rendering anything.
import fc from "fast-check";
import * as Island from "../../_build/default/test/compat/island/output/test/compat/island/economy.mjs";
import { tick } from "./harness.mjs";

const settle = async () => {
  for (let round = 0; round < 4; round++) await tick();
};

test("islands render only those whose props changed, and slot content alone renders none", async () => {
  await fc.assert(
    fc.asyncProperty(fc.array(fc.oneof(fc.constant("tick"), fc.nat(19)), { minLength: 1, maxLength: 12 }), async (actions) => {
      const root = document.body.appendChild(document.createElement("div"));
      const rendered = [];
      const client = Island.mount_page(root, (line) => rendered.push(line));
      await settle();
      expect(rendered.length).toBe(20);
      const values = Array(20).fill(0);
      let ticks = 0;
      for (const action of actions) {
        rendered.length = 0;
        if (action === "tick") {
          ticks++;
          root.querySelector(".tick").click();
        } else {
          values[action]++;
          root.querySelector(".bump-" + action).click();
        }
        await settle();
        expect(rendered).toEqual(action === "tick" ? [] : ["render c" + action]);
        expect(Array.from(root.querySelectorAll(".counted")).map((node) => node.firstChild.data)).toEqual(values.map(String));
        expect(Array.from(root.querySelectorAll(".tick-shown")).map((node) => node.textContent)).toEqual(Array(20).fill(String(ticks)));
      }
      Island.unmount_page(client);
      await settle();
      root.remove();
    }),
    { numRuns: 40 },
  );
}, 120000);
