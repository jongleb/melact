// The board of test/compat/bundle/app.mlx in a real browser, with react-dnd's HTML5 backend: Chromium drags
// cards with the mouse on two pages, the reason-react bundle on npm's React 18 and the Melact bundle coloured by
// melact.island's plugin, and both must show the same board, drag layer and chart and log the same drops, midway
// through each drag, once the hover has settled, and after it. Run: node test/compat/bundle/browser.mjs [--runs=12] [--headed]
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const repo = join(import.meta.dirname, "../../..");
const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, "").split("=")));
const runs = Number(args.runs ?? 12);
const { chromium } = await import(process.env.PLAYWRIGHT ?? "/Users/gleb/Home/wg/node_modules/playwright/index.mjs");

execFileSync("opam", ["exec", "--", "dune", "build", "test/compat/bundle"], { cwd: repo, stdio: "inherit" });
execFileSync("node", ["test/compat/bundle/build.mjs"], { cwd: repo, stdio: "inherit" });
const bundle = (side) => readFileSync(join(repo, `_build/default/test/compat/bundle/${side}/output/bundle.js`), "utf8");

const browser = await chromium.launch({ headless: !("headed" in args) });
const page = async (side) => {
  const opened = await browser.newPage({ viewport: { width: 900, height: 700 } });
  const errors = [];
  opened.on("pageerror", (error) => errors.push(error.message));
  await opened.setContent(`<!doctype html><html><body><div id="root"></div></body></html>`);
  await opened.addScriptTag({ content: bundle(side) });
  await opened.evaluate(() => {
    window.logged = [];
    window.App.mount_board_html5(document.getElementById("root"), (line) => window.logged.push(line));
  });
  await opened.waitForTimeout(100);
  return { side, page: opened, errors };
};

const handlers = (html) => {
  const names = new Map();
  return html.replace(/id="([ST])\d+"/g, (whole, kind) => {
    if (!names.has(whole)) names.set(whole, `id="${kind}${names.size}"`);
    return names.get(whole);
  });
};
// The DOM with attributes sorted and the wrappers of islands and slots shown as their children.
const canonical = () => {
  const walk = (node) => {
    if (node.nodeType === 3) return node.data === "" ? "" : JSON.stringify(node.data);
    if (node.nodeType !== 1) return "";
    const children = Array.from(node.childNodes).map(walk).join("");
    if (node.tagName === "MELACT-ISLAND" || node.tagName === "MELACT-SLOT") return children;
    const attributes = Array.from(node.attributes)
      .map((attribute) => `${attribute.name}=${JSON.stringify(attribute.value)}`)
      .sort()
      .join(" ");
    return `<${node.tagName.toLowerCase()} ${attributes}>${children}</>`;
  };
  return Array.from(document.getElementById("root").childNodes).map(walk).join("");
};
const seen = async (at) => ({
  html: handlers(await at.page.evaluate(canonical)),
  log: await at.page.evaluate(() => window.logged.slice()),
  errors: at.errors.slice(),
});

const drag = async (at, card, bin) => {
  const source = at.page.locator(`.card[title="${card}"]`);
  const target = at.page.locator(`.bin[title="${bin}"] h2`);
  const from = await source.boundingBox();
  const to = await target.boundingBox();
  await at.page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
  await at.page.mouse.down();
  await at.page.mouse.move(to.x + to.width / 2, to.y + to.height / 2, { steps: 8 });
  await at.page.waitForTimeout(300);
  await at.page.mouse.move(to.x + to.width / 2 + 2, to.y + to.height / 2, { steps: 2 });
  await at.page.waitForTimeout(300);
  const midway = await seen(at);
  await at.page.mouse.up();
  await at.page.waitForTimeout(80);
  return [midway, await seen(at)];
};

let seed = Number(args.seed ?? 7);
const random = (bound) => {
  seed = (seed * 1103515245 + 12345) % 2147483648;
  return Math.floor(seed / 65536) % bound;
};

let failed = 0;
for (let run = 0; run < runs; run++) {
  const moves = Array.from({ length: 1 + random(6) }, () => [["a", "b", "c"][random(3)], ["left", "right"][random(2)]]);
  const sides = [await page("react"), await page("melact")];
  const traces = [];
  for (const at of sides) {
    const trace = [await seen(at)];
    for (const [card, bin] of moves) trace.push(...(await drag(at, card, bin)));
    traces.push(trace);
    await at.page.close();
  }
  const [wanted, actual] = traces;
  const step = wanted.findIndex((shown, index) => JSON.stringify(shown) !== JSON.stringify(actual[index]));
  if (step >= 0) {
    failed++;
    console.log(`run ${run} ${JSON.stringify(moves)} differs at snapshot ${step}`);
    console.log("react ", JSON.stringify(wanted[step]).slice(0, 1500));
    console.log("melact", JSON.stringify(actual[step]).slice(0, 1500));
  } else console.log(`run ${run} ${JSON.stringify(moves)}: the same ${wanted.length} snapshots`);
}
await browser.close();
process.exit(failed === 0 ? 0 : 1);
