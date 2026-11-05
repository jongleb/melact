// Renders two builds of the same app in jsdom, drives both the same way, and compares the DOM after
// each step. Each build runs in its own process so React and Melact never share globals.
// Default: click every button in order. --explore: seeded random walks over buttons, links,
// checkboxes and text fields (typing, then sometimes submitting the form); every choice is made
// from the current DOM, so equal DOMs mean equal walks.
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
const mode = args[0]?.startsWith("--") ? args.shift() : "--press";
const seeds = [1, 2, 3, 4, 5];

if (args.length === 1) {
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
  Object.defineProperty(globalThis, "navigator", { value: dom.window.navigator, configurable: true });
  console.log = () => {};
  console.error = () => {};
  const settle = () => new Promise((resolve) => setTimeout(resolve, 20));
  await import(args[0]);
  await settle();
  const root = document.getElementById("root");
  const steps = [{ step: "mounted", html: root.innerHTML }];
  if (mode === "--press") {
    const count = root.querySelectorAll("button").length;
    for (let index = 0; index < count; index++) {
      for (let press = 0; press < 4; press++) {
        root.querySelectorAll("button")[index].click();
        await settle();
        steps.push({ step: `button ${index} press ${press + 1}`, html: root.innerHTML });
      }
    }
  } else {
    let state = Number(mode.split("=")[1]);
    const next = (bound) => {
      state = (state * 1103515245 + 12345) % 2147483648;
      return state % bound;
    };
    const words = ["milk", "eggs", "", "  ", "bread and butter", "x"];
    const setValue = Object.getOwnPropertyDescriptor(dom.window.HTMLInputElement.prototype, "value").set;
    for (let count = 0; count < 120; count++) {
      const targets = [...root.querySelectorAll("button, a[href], input")];
      const index = next(targets.length);
      const target = targets[index];
      let step = `${target.tagName.toLowerCase()} ${index}`;
      if (target.tagName === "INPUT" && target.type !== "checkbox") {
        const word = words[next(words.length)];
        setValue.call(target, word);
        target.dispatchEvent(new dom.window.Event("input", { bubbles: true }));
        await settle();
        step += ` typed "${word}"`;
        if (next(2) === 0 && target.form) {
          target.form.dispatchEvent(new dom.window.Event("submit", { bubbles: true, cancelable: true }));
          step += " and submitted";
        }
      } else {
        target.click();
      }
      await settle();
      steps.push({ step, html: root.innerHTML });
    }
  }
  process.stdout.write(JSON.stringify(steps), () => process.exit(0));
  await new Promise(() => {});
}

const run = (option, entry) =>
  JSON.parse(
    execFileSync(process.execPath, [fileURLToPath(import.meta.url), option, entry], {
      encoding: "utf8",
      maxBuffer: 1 << 26,
    }),
  );

const options = mode === "--press" ? ["--press"] : seeds.map((seed) => `--explore=${seed}`);
let total = 0;
let failed = 0;
for (const option of options) {
  const [expected, actual] = args.map((entry) => run(option, entry));
  total += expected.length;
  const index = expected.findIndex((step, at) => step.html !== actual[at]?.html);
  if (index >= 0) {
    failed++;
    const trail = expected.slice(Math.max(1, index - 3), index + 1).map((step) => step.step).join(", then ");
    console.log(`${option}: differs after ${trail}\n  react:  ${expected[index].html}\n  melact: ${actual[index]?.html}`);
  }
}
console.log(
  failed === 0
    ? `identical DOM after all ${total} steps`
    : `${failed} of ${options.length} runs differ`,
);
process.exit(failed === 0 ? 0 : 1);
