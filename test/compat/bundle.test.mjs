// An app with both kinds of JavaScript React library in one bundle: test/compat/bundle/app.mlx, a recharts
// chart on an island and react-dnd from OCaml components on melact.compat. Bundled by esbuild as an app is:
// with reason-react, everything on npm's React; with Melact, coloured by melact.island's plugin. Both bundles
// get the same drags and must show the same board and chart and log the same drops, and the plugin must
// bundle no module in both colours.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import fc from "fast-check";
import { run, tick } from "./harness.mjs";

execFileSync("node", ["test/compat/bundle/build.mjs"], { stdio: "inherit" });
const output = (side) => `_build/default/test/compat/bundle/${side}/output`;
const loaded = (side) => new Function(`${readFileSync(`${output(side)}/bundle.js`, "utf8")}; return App;`)();
const Reason = loaded("react");
const Melact = loaded("melact");
const duplicates = JSON.parse(readFileSync(`${output("melact")}/duplicates.json`, "utf8"));

const side = (name, build) => {
  const root = document.body.appendChild(document.createElement("div"));
  const layer = document.body.appendChild(document.createElement("div"));
  const at = {
    lib: { name },
    root,
    layer,
    log: [],
    mounted: undefined,
    dragging: false,
    build,
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

const handlers = (shown) => {
  const names = new Map();
  return shown.replace(/id="([ST])\d+"/g, (whole, kind) => {
    if (!names.has(whole)) names.set(whole, `id="${kind}${names.size}"`);
    return names.get(whole);
  });
};
const sides = () => [side("reason-react", Reason), Object.assign(side("melact", Melact), { relaxRoot: handlers })];
const app = (at) => () => at.build.mount_board(at.root, (line) => at.log.push(line));

// Each step of a drag is its own task, a frame or more after the last, as dragstart and dragover are separate
// events while a hand moves the card; dragend follows drop at once.
const perform = (at, [card, bin]) => {
  const backend = at.mounted[1].getBackend();
  const later = (count, step) => setTimeout(() => (count === 0 ? step() : later(count - 1, step)), 0);
  const source = at.root.querySelector(`.card[title="${card}"]`);
  const target = at.root.querySelector(`.bin[title="${bin}"]`);
  if (!source) return;
  backend.simulateBeginDrag([source.id]);
  later(4, () => {
    backend.simulateHover([target.id]);
    later(4, () => {
      backend.simulateDrop();
      backend.simulateEndDrag();
    });
  });
};

const move = fc.tuple(fc.constantFrom("a", "b", "c"), fc.constantFrom("left", "right"));

test("recharts on an island and react-dnd on melact.compat in one bundle agree with React 18", async () => {
  await run(sides(), app, [["a", "right"], ["b", "right"], ["a", "left"]], perform);
  await fc.assert(
    fc.asyncProperty(fc.array(move, { minLength: 1, maxLength: 8 }), async (moves) => {
      await run(sides(), app, moves, perform);
    }),
    { numRuns: 25 },
  );
  expect(duplicates).toEqual([]);
}, 600000);
