// Clone laws: test/clones/Clones.re, every way an element reaches React.cloneElement (a label through fold,
// forwarding, Children.map and Children.only, literals bound by let or written in the clone, branches of a
// switch mixing a label and literals), built with reason-react on React 18 and with Melact. Both builds get the
// same random renders, each with random clone plans (props objects over the element's labels and DOM props,
// undefined and click handlers among them) and random own props, and must show the same DOM and call the same
// handlers after every render and click.
import fc from "fast-check";
import * as Reason from "../../_build/default/test/clones/react/output/test/clones/react/Clones.mjs";
import * as Melact from "../../_build/default/test/clones/melact/output/test/clones/melact/Clones.mjs";
import { tick, shown } from "../compat/harness.mjs";

const plan = fc.record(
  {
    label: fc.string({ maxLength: 3 }),
    size: fc.nat(2),
    tone: fc.option(fc.string({ maxLength: 3 }), { nil: undefined }),
    count: fc.nat(9),
    className: fc.constantFrom("a", "b", ""),
    title: fc.option(fc.string({ maxLength: 3 }), { nil: undefined }),
    onClick: fc.constantFrom("p", "q"),
  },
  { requiredKeys: [] },
);

const state = fc.record({
  plans: fc.array(plan, { maxLength: 3 }),
  own: fc.string({ maxLength: 3 }),
  wrap: fc.nat(5),
  size: fc.nat(2),
  click: fc.nat(40),
});

// The plans as a side renders them: each onClick token becomes a handler that writes the token and the plan's place
// to the side's log.
const handled = (each, log) => ({
  ...each,
  plans: each.plans.map((plan, at) => (plan.onClick === undefined ? plan : { ...plan, onClick: () => log.push(plan.onClick + at) })),
});

const settle = async () => {
  for (let round = 0; round < 4; round++) await tick();
};

test("clones of elements from labels, forwarding, Children, local literals and branches show what React 18 shows", async () => {
  await fc.assert(
    fc.asyncProperty(fc.array(state, { minLength: 1, maxLength: 6 }), async (states) => {
      const traces = [];
      for (const build of [Reason, Melact]) {
        const root = document.body.appendChild(document.createElement("div"));
        const layer = document.body.appendChild(document.createElement("div"));
        const render = build.mount(root);
        const trace = [];
        const log = [];
        for (const each of states) {
          render(handled(each, log));
          await settle();
          const targets = root.querySelectorAll("b, em, u, i, button");
          targets[each.click % targets.length].click();
          await settle();
          trace.push(shown({ root, layer }).root, log.splice(0).join(","));
        }
        traces.push(trace);
        root.remove();
        layer.remove();
      }
      expect(traces[1]).toEqual(traces[0]);
    }),
    { numRuns: 80 },
  );
}, 240000);
