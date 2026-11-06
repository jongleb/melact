// A served TodoMVC page of 1,000 and 5,000 rows, hydrated at startup (?hydrate) or resumed at the
// first input (?resume), in headless Chrome: main-thread time and blocking time over the load, and the
// first click on a row's checkbox, pressed for --press ms (default 80).
//   DYLD_LIBRARY_PATH=/opt/homebrew/Cellar/simdjson/4.6.4/lib node bench/resume/run.mjs [--runs=9] [--rates=1,4]
import { spawn, spawnSync } from "node:child_process";
import { createServer } from "node:http";
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, "../..");
const chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const args = Object.fromEntries(process.argv.slice(2).map((a) => { const [, k, v] = a.match(/^--([^=]+)(?:=(.*))?$/s); return [k, v ?? "true"]; }));
const runs = Number(args.runs ?? 7);
const sizes = (args.sizes ?? "1000,5000").split(",").map(Number);
const rates = (args.rates ?? "1,4").split(",").map(Number);
const variants = (args.variants ?? "hydrate,resume").split(",");
const clickAt = Number(args["click-at"] ?? 0);
const log = (...p) => process.stderr.write(p.join(" ") + "\n");

const dist = join(here, "_dist");
if (!args["no-build"]) {
  rmSync(dist, { recursive: true, force: true });
  mkdirSync(dist, { recursive: true });
  spawnSync("opam", ["exec", "--", "dune", "build", "./bench/resume"], { cwd: repo, stdio: "inherit" });
  const stub = join(repo, "bench/resume/index.html");
  writeFileSync(stub, `<!doctype html><html><body><script type="module" src="/_build/default/bench/resume/client/output/bench/resume/client/main.mjs"></script></body></html>`);
  const { build } = await import(join(repo, "node_modules/vite/dist/node/index.js"));
  await build({ configFile: join(repo, "vite.config.js"), root: repo, base: "/", logLevel: "silent",
    build: { outDir: join(dist, "app"), emptyOutDir: true, minify: "esbuild", rollupOptions: { input: stub } } });
  rmSync(stub);
  const script = "/app/assets/" + readdirSync(join(dist, "app/assets")).find((f) => f.endsWith(".js"));
  for (const n of sizes) {
    const html = spawnSync(join(repo, "_build/default/bench/resume/server/server.exe"), [String(n)], { maxBuffer: 1 << 28 }).stdout.toString();
    writeFileSync(join(dist, `page${n}.html`), html.replace("SCRIPT", script));
  }
  writeFileSync(join(dist, "style.css"), readFileSync(join(here, "style.css")));
}

const server = await new Promise((done) => {
  const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };
  const s = createServer((req, res) => {
    const path = join(dist, decodeURIComponent(new URL(req.url, "http://x").pathname));
    if (!existsSync(path)) return res.writeHead(404).end();
    res.writeHead(200, { "content-type": types[extname(path)] ?? "application/octet-stream", "cache-control": "no-store" });
    res.end(readFileSync(path));
  });
  s.listen(0, "127.0.0.1", () => done(s));
});
const origin = `http://127.0.0.1:${server.address().port}`;

const profile = mkdtempSync(join(tmpdir(), "resume-"));
const chrome = spawn(chromePath, ["--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`, "--no-first-run",
  "--no-default-browser-check", "--disable-extensions", "--disable-background-timer-throttling",
  "--disable-backgrounding-occluded-windows", "--disable-renderer-backgrounding", "--window-size=1200,800", "about:blank"],
  { stdio: ["ignore", "ignore", "pipe"] });
const endpoint = await new Promise((done) => { let t = ""; chrome.stderr.on("data", (c) => { t += c; const m = t.match(/DevTools listening on (ws:\/\/\S+)/); if (m) done(m[1]); }); });
const socket = new WebSocket(endpoint);
await new Promise((d) => socket.addEventListener("open", d, { once: true }));
let counter = 0; const pending = new Map(); const listeners = new Set();
socket.addEventListener("message", ({ data }) => {
  const m = JSON.parse(data);
  if (m.id !== undefined) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.fail(new Error(JSON.stringify(m.error))) : p.done(m.result); }
  else for (const l of listeners) l(m);
});
const send = (method, params = {}, sessionId) => new Promise((done, fail) => { const id = ++counter; pending.set(id, { done, fail }); socket.send(JSON.stringify({ id, method, params, sessionId })); });
const wait = (ms) => new Promise((d) => setTimeout(d, ms));

const once = async (variant, n, rate) => {
  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
  const s = (m, p) => send(m, p, sessionId);
  const on = (method) => new Promise((done) => { const l = (m) => { if (m.sessionId === sessionId && m.method === method) { listeners.delete(l); done(m.params); } }; listeners.add(l); });
  await s("Page.enable"); await s("Runtime.enable");
  const errors = [];
  const errl = (m) => { if (m.sessionId === sessionId && m.method === "Runtime.exceptionThrown") errors.push(m.params.exceptionDetails.exception?.description); };
  listeners.add(errl);
  await s("Emulation.setCPUThrottlingRate", { rate });
  const events = [];
  const collect = (m) => { if (m.method === "Tracing.dataCollected") events.push(...m.params.value); };
  listeners.add(collect);
  await send("Tracing.start", { categories: "devtools.timeline,disabled-by-default-devtools.timeline,blink.user_timing,loading,toplevel", transferMode: "ReportEvents" });
  const loaded = on("Page.loadEventFired");
  await s("Page.navigate", { url: `${origin}/page${n}.html?${variant}` });
  await loaded;
  const evaluate = async (expression) => { const { result, exceptionDetails } = await s("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true }); if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text); return result.value; };
  // Let the page settle before the first click.
  await evaluate(`new Promise((d) => { const t0 = performance.now(); const go = () => { if (performance.now() - t0 > ${1500 + clickAt}) d(); else setTimeout(go, 50); }; go(); })`);
  const before = await evaluate(`document.querySelectorAll(".todo-list li")[5].className`);
  await evaluate(`(() => {
    let pressed = 0;
    addEventListener("pointerdown", (e) => { pressed = e.timeStamp; }, { capture: true, once: true });
    window.__latency = new Promise((done) => addEventListener("click", (e) => {
      const start = pressed;
      requestAnimationFrame(() => setTimeout(() => done(performance.now() - start), 0));
    }, { capture: true, once: true }));
    performance.mark("click:mark");
  })()`);
  const point = await evaluate(`(() => { const r = document.querySelectorAll(".todo-list li .toggle")[5].getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })()`);
  await s("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
  const pressedAt = Date.now();
  await s("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await wait(Math.max(0, Number(args.press ?? 80) - (Date.now() - pressedAt)));
  await s("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
  const latency = await evaluate(`window.__latency`);
  await evaluate(`new Promise((d) => setTimeout(d, 300))`);
  const after = await evaluate(`document.querySelectorAll(".todo-list li")[5].className`);
  const left = await evaluate(`document.querySelector(".todo-count strong").textContent`);
  const done = new Promise((d) => { const l = (m) => { if (m.method === "Tracing.tracingComplete") { listeners.delete(l); d(); } }; listeners.add(l); });
  await send("Tracing.end");
  await done;
  listeners.delete(collect); listeners.delete(errl);
  await send("Target.closeTarget", { targetId });

  const parse = events.find((e) => e.name === "ParseHTML" && JSON.stringify(e.args).includes(`page${n}.html`));
  const pid = parse.pid, tid = parse.tid;
  const nav = events.filter((e) => e.name === "navigationStart" && e.pid === pid && e.ts <= parse.ts).sort((a, b) => b.ts - a.ts)[0]
    ?? events.filter((e) => e.name === "navigationStart" && e.ts <= parse.ts).sort((a, b) => b.ts - a.ts)[0];
  const mark = (name) => events.find((e) => e.name === name && e.pid === pid);
  const clickTs = mark("click:mark").ts;
  const fcp = events.find((e) => e.name === "firstContentfulPaint" && e.pid === pid);
  const tasks = events.filter((e) => e.pid === pid && e.tid === tid && e.ph === "X" && (e.name === "RunTask" || e.name === "ThreadControllerImpl::RunTask") && e.ts >= nav.ts);
  const load = tasks.filter((t) => t.ts < clickTs);
  const clickTasks = tasks.filter((t) => t.ts >= clickTs);
  const busy = load.reduce((a, t) => a + t.dur, 0) / 1000;
  const tbt = load.filter((t) => t.ts >= (fcp?.ts ?? 0) && t.dur > 50000).reduce((a, t) => a + t.dur - 50000, 0) / 1000;
  const longest = load.reduce((a, t) => Math.max(a, t.dur), 0) / 1000;
  const lastLong = load.filter((t) => t.dur > 50000).reduce((a, t) => Math.max(a, t.ts + t.dur), nav.ts);
  const clickBusy = clickTasks.reduce((a, t) => Math.max(a, t.dur), 0) / 1000;
  if (args.breakdown) {
    const sums = {};
    for (const e of events) if (e.pid === pid && e.tid === tid && e.ph === "X" && e.ts >= nav.ts && e.ts < clickTs && !/RunTask/.test(e.name)) sums[e.name] = (sums[e.name] ?? 0) + e.dur / 1000;
    const after = {};
    for (const e of events) if (e.pid === pid && e.tid === tid && e.ph === "X" && e.ts >= clickTs && !/RunTask/.test(e.name)) after[e.name] = (after[e.name] ?? 0) + e.dur / 1000;
    const top = (o) => Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, 12).map(([k, v]) => `${k}=${v.toFixed(1)}`).join(" ");
    log(variant, "LOAD", top(sums)); log(variant, "CLICK", top(after));
  }
  return {
    busy, tbt, longest, fcp: fcp ? (fcp.ts - nav.ts) / 1000 : null,
    interactive: (lastLong - nav.ts) / 1000, latency, clickTask: clickBusy,
    correct: before !== after, errors: errors.length, left,
  };
};

const median = (xs) => { const s = xs.filter((x) => x !== null).sort((a, b) => a - b); return s.length ? s[Math.floor(s.length / 2)] : null; };
const results = {};
for (const n of sizes) for (const rate of rates) for (const variant of variants) {
  const samples = [];
  for (let i = 0; i < runs; i++) samples.push(await once(variant, n, rate));
  const keys = Object.keys(samples[0]).filter((k) => typeof samples[0][k] === "number");
  const row = Object.fromEntries(keys.map((k) => [k, median(samples.map((x) => x[k]))]));
  row.correct = samples.every((x) => x.correct && x.errors === 0);
  results[`${n} ${rate}x ${variant}`] = row;
  log(`${n} ${rate}x ${variant}`, JSON.stringify(row, (k, v) => (typeof v === "number" ? Math.round(v * 10) / 10 : v)));
}
writeFileSync(join(here, args.out ?? "results.json"), JSON.stringify(results, null, 1));
socket.close(); chrome.kill(); server.close();
try { rmSync(profile, { recursive: true, force: true }); } catch {}
