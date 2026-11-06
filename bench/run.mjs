import { spawn, spawnSync } from "node:child_process";
import { createServer } from "node:http";
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";

const bench = dirname(fileURLToPath(import.meta.url));
const repo = resolve(bench, "..");
const chromePath = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const [, key, value] = arg.match(/^--([^=]+)(?:=(.*))?$/s);
    return [key, value ?? "true"];
  }),
);
const runs = Number(args.runs ?? 10);
const memoryRuns = Number(args["memory-runs"] ?? 5);
const frameworks = (args.frameworks ?? "vanilla,meltea,melact,react").split(",");
const only = args.ops ? args.ops.split(",") : null;
if (args.alloc) args.profile = true;
const output = args.out ?? join(bench, args.profile ? "profile.json" : "results.json");
const dist = join(bench, args.profile ? "_dist-profile" : "_dist");

const log = (...parts) => process.stderr.write(parts.join(" ") + "\n");

const build = async () => {
  log("dune build ./bench");
  const dune = spawnSync("opam", ["exec", "--", "dune", "build", "./bench"], { cwd: repo, stdio: "inherit" });
  if (dune.status !== 0) throw new Error("dune build failed");
  const { build: viteBuild } = await import(join(repo, "node_modules/vite/dist/node/index.js"));
  for (const name of frameworks) {
    log("vite build", name);
    const outDir = join(dist, name);
    // Svelte and Vue Vapor build with their own Vite and plugins, from their own folder.
    const own = join(bench, name, "vite.config.mjs");
    if (existsSync(own)) {
      const built = spawnSync(
        process.execPath,
        [join(bench, name, "node_modules/vite/bin/vite.js"), "build", "--config", own, "--outDir", outDir],
        { cwd: repo, stdio: "inherit", env: { ...process.env, ...(args.profile ? { BENCH_PROFILE: "1" } : {}) } },
      );
      if (built.status !== 0) throw new Error(`vite build ${name} failed`);
      continue;
    }
    await viteBuild({
      configFile: join(repo, "vite.config.js"),
      root: repo,
      base: "./",
      logLevel: "silent",
      build: { outDir, emptyOutDir: true, minify: args.profile ? false : "esbuild", rollupOptions: { input: join(bench, name, "index.html") } },
    });
  }
};

const measureSizes = () => {
  const sizes = {};
  for (const name of frameworks) {
    const outDir = join(dist, name);
    let raw = 0;
    let gzip = 0;
    for (const file of readdirSync(join(outDir, "assets")))
      if (file.endsWith(".js")) {
        const bytes = readFileSync(join(outDir, "assets", file));
        raw += bytes.length;
        gzip += gzipSync(bytes, { level: 9 }).length;
      }
    sizes[name] = { raw, gzip };
  }
  return sizes;
};

const serve = () =>
  new Promise((done) => {
    const types = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".css": "text/css" };
    const server = createServer((request, response) => {
      const path = join(dist, decodeURIComponent(new URL(request.url, "http://x").pathname));
      if (!path.startsWith(dist) || !existsSync(path) || !statSync(path).isFile()) {
        response.writeHead(404).end();
        return;
      }
      response.writeHead(200, { "content-type": types[extname(path)] ?? "application/octet-stream", "cache-control": "no-store" });
      response.end(readFileSync(path));
    });
    server.listen(0, "127.0.0.1", () => done(server));
  });

const launch = async () => {
  const profile = mkdtempSync(join(tmpdir(), "melbench-"));
  const chrome = spawn(chromePath, [
    "--headless=new",
    "--remote-debugging-port=0",
    `--user-data-dir=${profile}`,
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-extensions",
    "--disable-background-timer-throttling",
    "--disable-backgrounding-occluded-windows",
    "--disable-renderer-backgrounding",
    "--disable-features=Translate,OptimizationHints,MediaRouter",
    "--window-size=1200,800",
    "about:blank",
  ], { stdio: ["ignore", "ignore", "pipe"] });
  const endpoint = await new Promise((done, fail) => {
    let text = "";
    chrome.stderr.on("data", (chunk) => {
      text += chunk;
      const found = text.match(/DevTools listening on (ws:\/\/\S+)/);
      if (found) done(found[1]);
    });
    chrome.on("exit", () => fail(new Error("chrome exited: " + text)));
  });
  const socket = new WebSocket(endpoint);
  await new Promise((done) => socket.addEventListener("open", done, { once: true }));
  let counter = 0;
  const pending = new Map();
  const listeners = new Set();
  socket.addEventListener("message", ({ data }) => {
    const message = JSON.parse(data);
    if (message.id !== undefined) {
      const { done, fail } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) fail(new Error(JSON.stringify(message.error)));
      else done(message.result);
    } else for (const listener of listeners) listener(message);
  });
  const send = (method, params = {}, sessionId) =>
    new Promise((done, fail) => {
      const id = ++counter;
      pending.set(id, { done, fail });
      socket.send(JSON.stringify({ id, method, params, sessionId }));
    });
  const close = () => {
    socket.close();
    chrome.kill();
    try {
      rmSync(profile, { recursive: true, force: true });
    } catch {}
  };
  return { send, listeners, close };
};

const openPage = async (browser, url) => {
  const { targetId } = await browser.send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await browser.send("Target.attachToTarget", { targetId, flatten: true });
  const send = (method, params) => browser.send(method, params, sessionId);
  const on = (method) =>
    new Promise((done) => {
      const listener = (message) => {
        if (message.sessionId === sessionId && message.method === method) {
          browser.listeners.delete(listener);
          done(message.params);
        }
      };
      browser.listeners.add(listener);
    });
  await send("Page.enable");
  await send("Runtime.enable");
  const exceptions = [];
  const listener = (message) => {
    if (message.sessionId === sessionId && message.method === "Runtime.exceptionThrown")
      exceptions.push(message.params.exceptionDetails.exception?.description ?? message.params.exceptionDetails.text);
  };
  browser.listeners.add(listener);
  const loaded = on("Page.loadEventFired");
  await send("Page.navigate", { url });
  await loaded;
  const evaluate = async (expression) => {
    const { result, exceptionDetails } = await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
    return result.value;
  };
  await evaluate(PAGE_HELPERS);
  await evaluate(`__until(() => document.getElementById("run") !== null)`);
  const click = async (selector) => {
    const point = await evaluate(`__point(${JSON.stringify(selector)})`);
    if (point === null) throw new Error("no element " + selector);
    await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
    await send("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
    await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
  };
  const close = async () => {
    browser.listeners.delete(listener);
    await browser.send("Target.closeTarget", { targetId });
  };
  return { send, on, evaluate, click, close, exceptions };
};

const PAGE_HELPERS = `
window.__frame = () => new Promise((done) => requestAnimationFrame(() => setTimeout(done, 0)));
window.__until = async (predicate, timeout = 20000) => {
  const start = performance.now();
  for (;;) {
    await __frame();
    if (predicate()) return true;
    if (performance.now() - start > timeout) throw new Error("timed out waiting for " + predicate);
  }
};
window.__point = (selector) => {
  const element = document.querySelector(selector);
  if (element === null) return null;
  element.scrollIntoView({ block: "nearest" });
  const rect = element.getBoundingClientRect();
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
};
window.__rows = () => document.querySelectorAll("table.test-data > tbody > tr");
window.__id = (n) => { const row = __rows()[n - 1]; return row ? Number(row.cells[0].textContent) : -1; };
window.__label = (n) => { const row = __rows()[n - 1]; return row ? row.cells[1].textContent : ""; };
window.__state = () => {
  const rows = Array.from(__rows());
  const words = /^(pretty|large|big|small|tall|short|long|handsome|plain|quaint|clean|elegant|easy|angry|crazy|helpful|mushy|odd|unsightly|adorable|important|inexpensive|cheap|expensive|fancy) (red|yellow|blue|green|pink|brown|purple|white|black|orange) (table|chair|house|bbq|desk|car|pony|cookie|sandwich|burger|pizza|mouse|keyboard)((?: !!!)*)$/;
  const problems = [];
  const ids = [];
  const bangs = [];
  const danger = [];
  rows.forEach((row, index) => {
    const cells = row.children;
    if (cells.length !== 4) problems.push("row " + index + " has " + cells.length + " cells");
    const shape = cells.length === 4 &&
      cells[0].className === "col-md-1" && cells[1].className === "col-md-4" && cells[2].className === "col-md-1" && cells[3].className === "col-md-6" &&
      cells[1].children.length === 1 && cells[1].firstElementChild.tagName === "A" &&
      cells[2].firstElementChild?.tagName === "A" && cells[2].firstElementChild.firstElementChild?.className === "glyphicon glyphicon-remove" &&
      cells[2].firstElementChild.firstElementChild.getAttribute("aria-hidden") === "true" && cells[3].childNodes.length === 0;
    if (!shape && problems.length < 5) problems.push("row " + index + " markup " + row.outerHTML.slice(0, 300));
    ids.push(Number(cells[0]?.textContent));
    const match = cells[1]?.textContent.match(words);
    if (!match) { if (problems.length < 5) problems.push("row " + index + " label " + JSON.stringify(cells[1]?.textContent)); bangs.push(-1); }
    else bangs.push(match[4].length / 4);
    const classes = row.className.split(/\\s+/).filter(Boolean);
    if (classes.includes("danger")) danger.push(index);
    if (classes.some((c) => c !== "danger") && problems.length < 5) problems.push("row " + index + " class " + row.className);
  });
  return { count: rows.length, ids, bangs, danger, problems, first: rows[0]?.outerHTML ?? null };
};
`;

const range = (from, count) => Array.from({ length: count }, (_, index) => from + index);
const W = 5;

const expectState = (state, { ids, bangs = () => 0, danger = [] }) => {
  const problems = [...state.problems];
  if (state.count !== ids.length) problems.push(`expected ${ids.length} rows, found ${state.count}`);
  const wrongId = ids.findIndex((id, index) => state.ids[index] !== id);
  if (wrongId >= 0) problems.push(`row ${wrongId}: expected id ${ids[wrongId]}, found ${state.ids[wrongId]}`);
  const wrongBang = state.bangs.findIndex((count, index) => count !== bangs(index));
  if (wrongBang >= 0) problems.push(`row ${wrongBang}: expected ${bangs(wrongBang)} " !!!", found ${state.bangs[wrongBang]}`);
  if (JSON.stringify(state.danger) !== JSON.stringify(danger)) problems.push(`selected rows ${JSON.stringify(state.danger)}, expected ${JSON.stringify(danger)}`);
  return problems;
};

const label = (row) => `table.test-data > tbody > tr:nth-of-type(${row}) > td:nth-of-type(2) > a`;
const remove = (row) => `table.test-data > tbody > tr:nth-of-type(${row}) > td:nth-of-type(3) > a > span`;

const runAndWait = async (page, selector, predicate) => {
  await page.click(selector);
  await page.evaluate(`__until(() => ${predicate})`);
};

const operations = [
  {
    name: "create rows",
    detail: "create 1,000 rows (5 warmups)",
    throttle: 1,
    init: async (page) => {
      for (let i = 0; i < W; i++) {
        await runAndWait(page, "#run", `__id(1) === ${i * 1000 + 1} && __rows().length === 1000`);
        await runAndWait(page, "#clear", `__rows().length === 0`);
      }
    },
    act: "#run",
    done: `__rows().length === 1000`,
    expect: { ids: range(W * 1000 + 1, 1000) },
  },
  {
    name: "replace all rows",
    detail: "replace 1,000 rows (5 warmups)",
    throttle: 1,
    init: async (page) => {
      for (let i = 0; i < W; i++) await runAndWait(page, "#run", `__id(1) === ${i * 1000 + 1} && __rows().length === 1000`);
    },
    act: "#run",
    done: `__id(1) === ${W * 1000 + 1}`,
    expect: { ids: range(W * 1000 + 1, 1000) },
  },
  {
    name: "partial update",
    detail: "update every 10th of 1,000 rows (3 warmups, 4x CPU slowdown)",
    throttle: 4,
    init: async (page) => {
      await runAndWait(page, "#run", `__rows().length === 1000`);
      for (let i = 0; i < 3; i++) await runAndWait(page, "#update", `__label(1).endsWith("${" !!!".repeat(i + 1)}")`);
    },
    act: "#update",
    done: `__label(1).endsWith("${" !!!".repeat(4)}")`,
    expect: { ids: range(1, 1000), bangs: (index) => (index % 10 === 0 ? 4 : 0) },
  },
  {
    name: "select row",
    detail: "highlight a row (5 warmups, 4x CPU slowdown)",
    throttle: 4,
    init: async (page) => {
      await runAndWait(page, "#run", `__rows().length === 1000`);
      for (let i = 0; i < W; i++) await runAndWait(page, label(i + 5), `__rows()[${i + 4}].className === "danger"`);
    },
    act: label(2),
    done: `__rows()[1].className === "danger"`,
    expect: { ids: range(1, 1000), danger: [1] },
  },
  {
    name: "swap rows",
    detail: "swap 2 rows of 1,000 (6 warmups, 4x CPU slowdown)",
    throttle: 4,
    init: async (page) => {
      await runAndWait(page, "#run", `__rows().length === 1000`);
      for (let i = 0; i <= W; i++) await runAndWait(page, "#swaprows", `__id(2) === ${i % 2 === 0 ? 999 : 2}`);
    },
    act: "#swaprows",
    done: `__id(2) === 999`,
    expect: { ids: range(1, 1000).map((id) => (id === 2 ? 999 : id === 999 ? 2 : id)) },
  },
  {
    name: "remove row",
    detail: "remove one row of 1,000 (5 warmups, 2x CPU slowdown)",
    throttle: 2,
    init: async (page) => {
      await runAndWait(page, "#run", `__rows().length === 1000`);
      for (let i = 0; i < W; i++) {
        const row = W - i + 4;
        await runAndWait(page, remove(row), `__id(${row}) === ${row + i + 1} && __rows().length === ${999 - i}`);
      }
    },
    act: remove(4),
    done: `__id(4) === 10`,
    expect: { ids: [1, 2, 3, ...range(10, 991)] },
  },
  {
    name: "create many rows",
    detail: "create 10,000 rows (5 warmups)",
    throttle: 1,
    init: async (page) => {
      for (let i = 0; i < W; i++) {
        await runAndWait(page, "#run", `__id(1) === ${i * 1000 + 1} && __rows().length === 1000`);
        await runAndWait(page, "#clear", `__rows().length === 0`);
      }
    },
    act: "#runlots",
    done: `__rows().length === 10000`,
    expect: { ids: range(W * 1000 + 1, 10000) },
  },
  {
    name: "append rows",
    detail: "append 1,000 to 1,000 rows (5 warmups)",
    throttle: 1,
    init: async (page) => {
      for (let i = 0; i < W; i++) {
        await runAndWait(page, "#run", `__id(1) === ${i * 1000 + 1} && __rows().length === 1000`);
        await runAndWait(page, "#clear", `__rows().length === 0`);
      }
      await runAndWait(page, "#run", `__rows().length === 1000`);
    },
    act: "#add",
    done: `__rows().length === 2000`,
    expect: { ids: range(W * 1000 + 1, 2000) },
  },
  {
    name: "clear rows",
    detail: "clear 1,000 rows (5 warmups, 4x CPU slowdown)",
    throttle: 4,
    init: async (page) => {
      for (let i = 0; i < W; i++) {
        await runAndWait(page, "#run", `__id(1) === ${i * 1000 + 1} && __rows().length === 1000`);
        await runAndWait(page, "#clear", `__rows().length === 0`);
      }
      await runAndWait(page, "#run", `__rows().length === 1000`);
    },
    act: "#clear",
    done: `__rows().length === 0`,
    expect: { ids: [] },
  },
];

const CATEGORIES = [
  "devtools.timeline",
  "disabled-by-default-devtools.timeline",
  "disabled-by-default-devtools.timeline.frame",
  "blink.user_timing",
  "v8.execute",
  "toplevel",
].join(",");

const SCRIPT = new Set(["EventDispatch", "FunctionCall", "RunMicrotasks", "TimerFire", "FireAnimationFrame", "v8.run", "EvaluateScript"]);
const STYLE = new Set(["UpdateLayoutTree", "Layout", "RecalculateStyles"]);
const PAINT = new Set(["PrePaint", "Paint", "Layerize", "Commit", "UpdateLayer", "CompositeLayers"]);
const TASK = new Set(["RunTask", "ThreadControllerImpl::RunTask"]);

const covered = (events, from, to) => {
  const spans = events
    .map((event) => [Math.max(event.ts, from), Math.min(event.ts + (event.dur ?? 0), to)])
    .filter(([start, stop]) => stop > start)
    .sort((a, b) => a[0] - b[0]);
  let sum = 0;
  let reach = -Infinity;
  for (const [start, stop] of spans) {
    if (stop <= reach) continue;
    sum += stop - Math.max(start, reach);
    reach = stop;
  }
  return sum / 1000;
};

const analyse = (events) => {
  const click = events.find((event) => event.name === "EventDispatch" && event.args?.data?.type === "click");
  if (!click) throw new Error("no click in trace");
  const main = events.filter((event) => event.pid === click.pid && event.tid === click.tid && event.ph === "X" && event.ts + (event.dur ?? 0) >= click.ts);
  const paint = main.filter((event) => event.name === "Paint" && event.ts >= click.ts).sort((a, b) => a.ts - b.ts)[0];
  if (!paint) throw new Error("no paint after click");
  const commit = main.filter((event) => event.name === "Commit" && event.ts >= paint.ts).sort((a, b) => a.ts - b.ts)[0];
  const end = Math.max(paint.ts + paint.dur, commit ? commit.ts + commit.dur : 0);
  const pick = (names) => main.filter((event) => names.has(event.name));
  return {
    busy: covered(pick(TASK), click.ts, end),
    wall: (end - click.ts) / 1000,
    script: covered(pick(SCRIPT), click.ts, paint.ts),
    style: covered(pick(STYLE), click.ts, end),
    paint: covered(pick(PAINT), click.ts, end),
    gc: covered(main.filter((event) => /^(MajorGC|MinorGC|V8\.GC_)/.test(event.name)), click.ts, end),
    marking: covered(
      events.filter((event) => event.pid === click.pid && event.tid !== click.tid && event.name.startsWith("V8.GC_MC_BACKGROUND_MARKING")),
      click.ts,
      end,
    ),
  };
};

const measure = async (browser, url, operation) => {
  const page = await openPage(browser, url);
  try {
    await operation.init(page);
    await page.evaluate(`__frame()`);
    await page.evaluate(`__frame()`);
    const point = await page.evaluate(`__point(${JSON.stringify(operation.act)})`);
    if (point === null) throw new Error("no element " + operation.act);
    if (args.before) await page.evaluate(args.before);
    await page.send("Emulation.setCPUThrottlingRate", { rate: operation.throttle });
    const events = [];
    const listener = (message) => {
      if (message.method === "Tracing.dataCollected") events.push(...message.params.value);
    };
    browser.listeners.add(listener);
    await browser.send("Tracing.start", { traceConfig: { includedCategories: CATEGORIES.split(","), recordMode: "recordAsMuchAsPossible" }, transferMode: "ReportEvents" });
    await page.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
    await page.send("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
    await page.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
    await page.evaluate(`__until(() => ${operation.done})`);
    await page.evaluate(`__frame()`);
    const complete = new Promise((done) => {
      const finished = (message) => {
        if (message.method === "Tracing.tracingComplete") {
          browser.listeners.delete(finished);
          done();
        }
      };
      browser.listeners.add(finished);
    });
    await browser.send("Tracing.end");
    await complete;
    browser.listeners.delete(listener);
    await page.send("Emulation.setCPUThrottlingRate", { rate: 1 });
    const timing = analyse(events);
    if (args.trace) writeFileSync(join(args.trace, `${operation.name.replaceAll(" ", "-")}-${url.split("/")[3]}.json`), JSON.stringify({ traceEvents: events }));
    const state = await page.evaluate(`__state()`);
    if (args.probe) log("probe", JSON.stringify(await page.evaluate(args.probe)));
    const problems = [...expectState(state, operation.expect), ...page.exceptions];
    return { ...timing, problems, first: state.first };
  } finally {
    await page.close();
  }
};

const profile = async (browser, url, operation) => {
  const page = await openPage(browser, url);
  try {
    await operation.init(page);
    await page.evaluate(`__frame()`);
    const point = await page.evaluate(`__point(${JSON.stringify(operation.act)})`);
    if (args.alloc) {
      await page.send("HeapProfiler.enable");
      await page.send("HeapProfiler.startSampling", { samplingInterval: 256 });
    } else {
      await page.send("Profiler.enable");
      await page.send("Profiler.setSamplingInterval", { interval: 50 });
      await page.send("Emulation.setCPUThrottlingRate", { rate: operation.throttle });
      await page.send("Profiler.start");
    }
    await page.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
    await page.send("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
    await page.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
    await page.evaluate(`__until(() => ${operation.done})`);
    const self = new Map();
    if (args.alloc) {
      const { profile: heap } = await page.send("HeapProfiler.stopSampling");
      const visit = (node) => {
        const frame = node.callFrame;
        const key = `${frame.functionName || "(anonymous)"} ${frame.url.split("/").pop()}:${frame.lineNumber + 1}`;
        if (node.selfSize) self.set(key, (self.get(key) ?? 0) + node.selfSize / 1024);
        node.children.forEach(visit);
      };
      visit(heap.head);
      const state = await page.evaluate(`__state()`);
      return { self, problems: [...expectState(state, operation.expect), ...page.exceptions] };
    }
    const { profile: data } = await page.send("Profiler.stop");
    await page.send("Emulation.setCPUThrottlingRate", { rate: 1 });
    const nodes = new Map(data.nodes.map((node) => [node.id, node]));
    data.samples.forEach((id, index) => {
      const frame = nodes.get(id).callFrame;
      if (["(idle)", "(program)", "(root)"].includes(frame.functionName)) return;
      if (frame.url === "" && !frame.functionName.startsWith("(")) return;
      const key = `${frame.functionName || "(anonymous)"} ${frame.url.split("/").pop()}:${frame.lineNumber + 1}`;
      self.set(key, (self.get(key) ?? 0) + data.timeDeltas[index] / 1000);
    });
    const state = await page.evaluate(`__state()`);
    return { self, problems: [...expectState(state, operation.expect), ...page.exceptions] };
  } finally {
    await page.close();
  }
};

const memory = async (browser, url) => {
  const page = await openPage(browser, url);
  try {
    const heap = async () => {
      await page.evaluate(`__frame()`);
      await page.send("HeapProfiler.collectGarbage");
      await page.send("HeapProfiler.collectGarbage");
      return (await page.send("Runtime.getHeapUsage")).usedSize / 1048576;
    };
    await page.send("HeapProfiler.enable");
    const ready = await heap();
    await runAndWait(page, "#run", `__rows().length === 1000`);
    const created = await heap();
    for (let i = 0; i < 5; i++) {
      await runAndWait(page, "#run", `__id(1) === ${(i + 1) * 1000 + 1}`);
      await runAndWait(page, "#clear", `__rows().length === 0`);
    }
    const cycled = await heap();
    return { ready, created, cycled, problems: page.exceptions };
  } finally {
    await page.close();
  }
};

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = sorted.length >> 1;
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
};

const main = async () => {
  if (!args["no-build"]) await build();
  const sizes = measureSizes();
  const server = await serve();
  const { port } = server.address();
  const urlOf = (name) => `http://127.0.0.1:${port}/${name}/bench/${name}/index.html`;
  const results = { date: new Date().toISOString(), chrome: "", runs, sizes, cpu: {}, memory: {}, problems: [] };
  const browser = await launch();
  try {
    results.chrome = (await browser.send("Browser.getVersion")).product;
    const chosen = operations.filter((operation) => !only || only.includes(operation.name));
    for (const operation of chosen) {
      results.cpu[operation.name] = { detail: operation.detail };
      const samples = Object.fromEntries(frameworks.map((name) => [name, []]));
      for (let run = 0; run < runs; run++)
        for (const name of frameworks) {
          const sample = await (args.profile ? profile : measure)(browser, urlOf(name), operation);
          if (sample.problems.length) results.problems.push({ framework: name, operation: operation.name, run, problems: sample.problems });
          samples[name].push(sample);
        }
      for (const name of frameworks) {
        if (args.profile) {
          const self = new Map();
          for (const sample of samples[name]) for (const [key, time] of sample.self) self.set(key, (self.get(key) ?? 0) + time / runs);
          const total = [...self.values()].reduce((sum, time) => sum + time, 0);
          const top = [...self.entries()].sort((a, b) => b[1] - a[1]).slice(0, Number(args.top ?? 15));
          results.cpu[operation.name][name] = { total, top };
          const unit = args.alloc ? "kB" : "ms";
          log(`\n${operation.name} / ${name}: ${total.toFixed(2)} ${unit} of samples per run`);
          for (const [key, time] of top) log(`  ${time.toFixed(2).padStart(7)} ${unit}  ${key}`);
          continue;
        }
        const of = (key) => median(samples[name].map((sample) => sample[key]));
        const totals = samples[name].map((sample) => sample.busy);
        results.cpu[operation.name][name] = {
          median: median(totals),
          wall: of("wall"),
          script: of("script"),
          style: of("style"),
          paint: of("paint"),
          gc: of("gc"),
          marking: of("marking"),
          min: Math.min(...totals),
          max: Math.max(...totals),
          samples: totals,
          first: samples[name][0].first,
        };
        log(`${operation.name.padEnd(18)} ${name.padEnd(8)} ${median(totals).toFixed(1).padStart(7)} ms  script ${of("script").toFixed(1)}  style+layout ${of("style").toFixed(1)}  paint ${of("paint").toFixed(1)}  gc ${of("gc").toFixed(1)}  bg-marking ${of("marking").toFixed(1)}  wall ${of("wall").toFixed(1)}${samples[name].some((s) => s.problems.length) ? "  WRONG" : ""}`);
      }
    }
    if (!only || only.includes("memory"))
      for (const name of frameworks) {
        const samples = [];
        for (let run = 0; run < memoryRuns; run++) samples.push(await memory(browser, urlOf(name)));
        for (const sample of samples) if (sample.problems.length) results.problems.push({ framework: name, operation: "memory", problems: sample.problems });
        results.memory[name] = Object.fromEntries(["ready", "created", "cycled"].map((key) => [key, median(samples.map((sample) => sample[key]))]));
        log(`memory ${name.padEnd(8)} ready ${results.memory[name].ready.toFixed(2)} MB, 1k rows ${results.memory[name].created.toFixed(2)} MB, after 5 create/clear ${results.memory[name].cycled.toFixed(2)} MB`);
      }
  } finally {
    browser.close();
    server.close();
  }
  writeFileSync(output, JSON.stringify(results, null, 2));
  if (!args.profile) process.stdout.write(report(results) + "\n");
};

const report = (results) => {
  const names = frameworks;
  const lines = [];
  lines.push(`Chrome ${results.chrome}, ${results.runs} fresh page loads per cell, median main-thread busy ms from the click to the end of the next frame's paint commit (idle vsync wait excluded; script ms in parentheses).`);
  lines.push("");
  lines.push(`| operation | ${names.join(" | ")} |`);
  lines.push(`|---|${names.map(() => "---:").join("|")}|`);
  const slowdowns = Object.fromEntries(names.map((name) => [name, []]));
  for (const [operation, cells] of Object.entries(results.cpu)) {
    const base = cells.vanilla?.median;
    lines.push(
      `| ${operation} <br><sub>${cells.detail}</sub> | ${names
        .map((name) => {
          const cell = cells[name];
          if (!cell) return "";
          if (base) slowdowns[name].push(cell.median / base);
          return `${cell.median.toFixed(1)} (${cell.script.toFixed(1)})${base && name !== "vanilla" ? ` ×${(cell.median / base).toFixed(2)}` : ""}`;
        })
        .join(" | ")} |`,
    );
  }
  lines.push(
    `| **geometric mean of slowdown vs vanilla** | ${names
      .map((name) => {
        const values = slowdowns[name];
        return values.length ? (Math.exp(values.reduce((sum, value) => sum + Math.log(value), 0) / values.length)).toFixed(2) : "";
      })
      .join(" | ")} |`,
  );
  lines.push("");
  lines.push(`| size and memory | ${names.join(" | ")} |`);
  lines.push(`|---|${names.map(() => "---:").join("|")}|`);
  lines.push(`| JS bundle, kB (gzip -9) | ${names.map((name) => results.sizes[name] ? `${(results.sizes[name].gzip / 1024).toFixed(1)} (raw ${(results.sizes[name].raw / 1024).toFixed(1)})` : "").join(" | ")} |`);
  if (Object.keys(results.memory).length) {
    lines.push(`| ready heap, MB | ${names.map((name) => results.memory[name]?.ready.toFixed(2) ?? "").join(" | ")} |`);
    lines.push(`| heap with 1,000 rows, MB | ${names.map((name) => results.memory[name]?.created.toFixed(2) ?? "").join(" | ")} |`);
    lines.push(`| heap after 5 × create/clear, MB | ${names.map((name) => results.memory[name]?.cycled.toFixed(2) ?? "").join(" | ")} |`);
  }
  lines.push("");
  if (results.problems.length) {
    lines.push("Correctness problems:");
    for (const problem of results.problems) lines.push(`- ${problem.framework} / ${problem.operation}: ${problem.problems.slice(0, 3).join("; ")}`);
  } else lines.push("Every run passed the correctness checks.");
  return lines.join("\n");
};

await main();
