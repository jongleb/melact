// react-dnd on melact.compat: test/compat/dnd.mlx, cards and bins whose useDrag and useDrop OCaml components
// call, built with reason-react on npm's React 18 and with Melact on the shim. react-dnd's test backend drags
// the same cards over the same bins on both, and they must show the same board and log the same drops.
import fc from "fast-check";
import * as Reason from "../../_build/default/test/compat/react/output/test/compat/react/dnd.mjs";
import * as Melact from "../../_build/default/test/compat/melact/output/test/compat/melact/dnd.mjs";
import { run, tick } from "./harness.mjs";

const side = (name, build) => {
  const root = document.body.appendChild(document.createElement("div"));
  const layer = document.body.appendChild(document.createElement("div"));
  const log = [];
  const at = {
    lib: { name },
    root,
    layer,
    log,
    mounted: undefined,
    dragging: false,
    async settle(act) {
      act?.();
      for (let round = 0; round < 40; round++) await tick();
    },
    async render(begin) {
      await at.settle(() => {
        at.mounted = begin();
      });
    },
    async unmount() {
      await at.settle(() => build.unmount_board(at.mounted));
      root.remove();
      layer.remove();
    },
  };
  return at;
};

// react-dnd numbers its handlers with counters of its module, which the two builds load apart.
const handlers = (shown) => {
  const names = new Map();
  return shown.replace(/id="([ST])\d+"/g, (whole, kind) => {
    if (!names.has(whole)) names.set(whole, `id="${kind}${names.size}"`);
    return names.get(whole);
  });
};
const sides = () => [side("reason-react", Reason), Object.assign(side("melact.compat", Melact), { relaxRoot: handlers })];
const app = (at) => () => (at.lib.name === "reason-react" ? Reason : Melact).mount_board(at.root, (line) => at.log.push(line));

// Each step of a drag is its own task, a frame or more after the last, as dragstart and dragover are
// separate events while a hand moves the card; dragend follows drop at once.
const perform = (at, [kind, card, bin]) => {
  const backend = at.mounted[1].getBackend();
  const steps = [];
  if (at.dragging) {
    steps.push(() => backend.simulateEndDrag());
    at.dragging = false;
  }
  steps.push(() => {
    const source = at.root.querySelector(`.card[title="${card}"]`);
    const target = at.root.querySelector(`.bin[title="${bin}"]`);
    if (!source) return [];
    backend.simulateBeginDrag([source.id]);
    if (kind === "peek") at.dragging = true;
    return kind === "peek"
      ? [() => backend.simulateHover([target.id])]
      : [
          () => backend.simulateHover([target.id]),
          () => {
            backend.simulateDrop();
            backend.simulateEndDrag();
          },
        ];
  });
  const next = (queue) => {
    if (queue.length === 0) return;
    const more = queue[0]() ?? [];
    const later = (count, run) => setTimeout(() => (count === 0 ? run() : later(count - 1, run)), 0);
    later(4, () => next([...more, ...queue.slice(1)]));
  };
  next(steps);
};

const action = fc.tuple(fc.constantFrom("move", "peek"), fc.constantFrom("a", "b", "c"), fc.constantFrom("left", "right"));

test("cards dragged between bins with react-dnd from OCaml components on melact.compat agree with React 18", async () => {
  await run(sides(), app, [["move", "a", "right"], ["peek", "b", "right"], ["move", "c", "right"], ["move", "a", "left"]], perform);
  await fc.assert(
    fc.asyncProperty(fc.array(action, { minLength: 1, maxLength: 12 }), async (actions) => {
      await run(sides(), app, actions, perform);
    }),
    { numRuns: 40 },
  );
}, 240000);
