// Renders two builds of the same app in jsdom, clicks every button in order, and compares the DOM
// after each step. Each build runs in its own process so React and melact never share globals.
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const [, , ...entries] = process.argv;

if (entries.length === 1) {
  const { JSDOM } = await import("jsdom");
  const dom = new JSDOM(`<!doctype html><div id="root"></div>`, {
    pretendToBeVisual: true,
    url: "http://localhost/",
  });
  for (const name of Object.getOwnPropertyNames(dom.window)) {
    if (!(name in globalThis)) globalThis[name] = dom.window[name];
  }
  globalThis.window = dom.window;
  globalThis.document = dom.window.document;
  globalThis.navigator = dom.window.navigator;
  console.log = () => {};
  console.error = () => {};
  const settle = () => new Promise((resolve) => setTimeout(resolve, 60));
  await import(entries[0]);
  await settle();
  const root = document.getElementById("root");
  const steps = [{ step: "mounted", html: root.innerHTML }];
  const count = root.querySelectorAll("button").length;
  for (let index = 0; index < count; index++) {
    for (let press = 0; press < 4; press++) {
      root.querySelectorAll("button")[index].click();
      await settle();
      steps.push({ step: `button ${index} press ${press + 1}`, html: root.innerHTML });
    }
  }
  process.stdout.write(JSON.stringify(steps));
  process.exit(0);
}

const run = (entry) =>
  JSON.parse(
    execFileSync(process.execPath, [fileURLToPath(import.meta.url), entry], {
      encoding: "utf8",
      maxBuffer: 1 << 26,
    }),
  );

const [expected, actual] = entries.map(run);
const differences = expected.filter((step, index) => step.html !== actual[index]?.html);
for (const step of differences.slice(0, 3)) {
  const index = expected.indexOf(step);
  console.log(`differs after ${step.step}:\n  react:  ${step.html}\n  melact: ${actual[index]?.html}`);
}
console.log(
  differences.length === 0
    ? `identical DOM after all ${expected.length} steps`
    : `${differences.length} of ${expected.length} steps differ`,
);
process.exit(differences.length === 0 ? 0 : 1);
