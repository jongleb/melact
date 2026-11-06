import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { performance } from "node:perf_hooks";
import { CATEGORIES, PAGE_HELPERS, PAINT, SCRIPT, STYLE, TASK, analyse, covered, launch, measureSizes, median, serve } from "../run.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "../..");
const dist = join(here, "_dist");

const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const [, key, value] = arg.match(/^--([^=]+)(?:=(.*))?$/s);
    return [key, value ?? "true"];
  }),
);
const list = (value) => value.split(",").filter(Boolean);
const sizes = list(args.rows ?? "1000,10000").map(Number);
const warmups = Number(args.warmups ?? 20);
const iterations = args.iterations ? Number(args.iterations) : null;
const runs = Number(args.runs ?? 10);
const throttles = list(args.throttles ?? "1,4").map(Number);
const suites = list(args.suites ?? "ssr,hydration");
const log = (...parts) => process.stderr.write(parts.join(" ") + "\n");

// The same deterministic rows for every framework; the native Meltea server builds them with the same formula.
const ADJECTIVES = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"];
const COLOURS = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange"];
const NOUNS = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"];
const rowsOf = (count) =>
  Array.from({ length: count }, (_, index) => ({
    id: index + 1,
    label: `${ADJECTIVES[index % 25]} ${COLOURS[index % 11]} ${NOUNS[index % 13]}`,
  }));

const NATIVE = join(repo, "_build/default/bench/ssr/meltea/server/server.exe");

// Server renderers. Each Node one is a module with `render(prepare(rows))`, run in a fresh Node process.
const RENDERERS = {
  "meltea-native": { label: "Meltea, native OCaml (meltea.server)", native: NATIVE },
  "meltea-node": { label: "Meltea, Melange in Node (meltea.server)", module: "_build/default/bench/ssr/meltea/node/output/bench/ssr/meltea/node/ssr.mjs" },
  "melact-linkedom": { label: "Melact renderToString, Node + linkedom", module: "_build/default/bench/ssr/melact/node/output/bench/ssr/melact/node/ssr.mjs", dom: "linkedom" },
  "melact-jsdom": { label: "Melact renderToString, Node + jsdom", module: "_build/default/bench/ssr/melact/node/output/bench/ssr/melact/node/ssr.mjs", dom: "jsdom" },
  react: { label: "React 18.3 renderToString, Node", module: "bench/ssr/react/_server/server.js" },
  svelte: { label: "Svelte 5 render (svelte/server), Node", module: "bench/ssr/svelte/_server/server.js" },
};
const renderers = list(args.renderers ?? Object.keys(RENDERERS).join(","));

// Hydrating clients, and the renderer whose HTML each one is served.
const CLIENTS = {
  meltea: { server: "meltea-native", own: false },
  melact: { server: "melact-linkedom", own: false },
  react: { server: "react", own: true },
  svelte: { server: "svelte", own: true },
};
const frameworks = list(args.frameworks ?? Object.keys(CLIENTS).join(","));

const iterationsFor = (count) => iterations ?? (count >= 10000 ? 50 : 200);

const child = async () => {
  process.env.NODE_ENV = "production";
  const renderer = RENDERERS[args.child];
  if (renderer.dom === "linkedom") {
    const { parseHTML } = await import(pathToFileURL(join(here, "node_modules/linkedom/esm/index.js")).href);
    const { window, document } = parseHTML("<!doctype html><html><head></head><body></body></html>");
    Object.assign(globalThis, { window, document });
  }
  if (renderer.dom === "jsdom") {
    const { JSDOM } = await import(pathToFileURL(join(repo, "node_modules/jsdom/lib/api.js")).href);
    const { window } = new JSDOM("<!doctype html><html><head></head><body></body></html>");
    Object.assign(globalThis, { window, document: window.document });
  }
  const app = await import(pathToFileURL(join(repo, renderer.module)).href);
  const props = (app.prepare ?? ((rows) => rows))(rowsOf(Number(args.count)));
  let html = app.render(props);
  for (let index = 0; index < Number(args.warmups); index++) html = app.render(props);
  const samples = [];
  const sent = [];
  for (let index = 0; index < Number(args.iterations); index++) {
    const start = performance.now();
    html = app.render(props);
    const rendered = performance.now();
    Buffer.from(html, "utf8");
    const encoded = performance.now();
    samples.push(rendered - start);
    sent.push(encoded - start);
  }
  process.stdout.write(JSON.stringify({ samples, sent, html }));
};

const run = (command, commandArgs, options = {}) => {
  const done = spawnSync(command, commandArgs, { cwd: repo, maxBuffer: 1 << 30, encoding: "utf8", ...options });
  if (done.status !== 0) throw new Error(`${command} ${commandArgs.join(" ")} failed:\n${done.stderr}`);
  return done.stdout;
};

const renderWith = (name, count, warm, many) => {
  const renderer = RENDERERS[name];
  if (renderer.native) {
    const samples = JSON.parse(run(renderer.native, ["time", String(count), String(warm), String(many)]));
    return { samples, sent: samples, html: run(renderer.native, ["html", String(count)]) };
  }
  return JSON.parse(
    run(process.execPath, [fileURLToPath(import.meta.url), `--child=${name}`, `--count=${count}`, `--warmups=${warm}`, `--iterations=${many}`]),
  );
};

const build = async () => {
  log("dune build ./bench/ssr");
  run("opam", ["exec", "--", "dune", "build", "./bench/ssr"], { stdio: "inherit" });
  for (const name of ["react", "svelte"]) {
    log("vite build --ssr", name);
    const entry = name === "react" ? "server.jsx" : "server.js";
    run(process.execPath, [join(here, name, "node_modules/vite/bin/vite.js"), "build", "--config", join(here, name, "vite.config.mjs"), "--ssr", `bench/ssr/${name}/src/${entry}`, "--outDir", join(here, name, "_server")], { stdio: "inherit" });
  }
  const { build: viteBuild } = await import(pathToFileURL(join(repo, "node_modules/vite/dist/node/index.js")).href);
  for (const name of frameworks) {
    log("vite build", name);
    const outDir = join(dist, name);
    if (CLIENTS[name].own)
      run(process.execPath, [join(here, name, "node_modules/vite/bin/vite.js"), "build", "--config", join(here, name, "vite.config.mjs"), "--outDir", outDir], { stdio: "inherit" });
    else
      await viteBuild({
        configFile: join(repo, "vite.config.js"),
        root: repo,
        base: "./",
        logLevel: "silent",
        build: { outDir, emptyOutDir: true, minify: "esbuild", rollupOptions: { input: join(here, name, "index.html") } },
      });
  }
};

const linkedom = async () => (await import(pathToFileURL(join(here, "node_modules/linkedom/esm/index.js")).href)).parseHTML;

// What a page shows: tags, attributes (an empty class counts as none), texts joined; comments dropped.
const digestOf = (parseHTML, html) => {
  const { document } = parseHTML(`<!doctype html><html><body><div id="main">${html}</div></body></html>`);
  const normal = (node) => {
    const attributes = Array.from(node.attributes)
      .filter((attribute) => !(attribute.name === "class" && attribute.value === ""))
      .map((attribute) => `${attribute.name}=${attribute.value}`)
      .sort()
      .join(" ");
    const parts = [];
    let text = "";
    for (const child of node.childNodes) {
      if (child.nodeType === 3) text += child.data;
      else if (child.nodeType === 1) {
        if (text) parts.push(JSON.stringify(text));
        text = "";
        parts.push(normal(child));
      }
    }
    if (text) parts.push(JSON.stringify(text));
    return `<${node.tagName.toLowerCase()} ${attributes}>${parts.join("")}</>`;
  };
  const main = document.getElementById("main");
  const rows = Array.from(main.querySelectorAll("table.test-data > tbody > tr"));
  return { digest: normal(main), rows: rows.length, text: main.textContent, rowTexts: rows.map((row) => row.textContent) };
};

const ssr = async (results) => {
  const parseHTML = await linkedom();
  results.ssr = {};
  for (const count of sizes) {
    const expected = rowsOf(count);
    results.ssr[count] = {};
    let reference = null;
    const written = {};
    for (const name of renderers) {
      log(`ssr ${name} ${count} rows: ${warmups} warmups, ${iterationsFor(count)} renders`);
      const { samples, sent, html } = renderWith(name, count, warmups, iterationsFor(count));
      const seen = digestOf(parseHTML, html);
      const problems = [];
      if (seen.rows !== count) problems.push(`${seen.rows} rows, expected ${count}`);
      const wrong = expected.findIndex((row, index) => seen.rowTexts[index] !== `${row.id}${row.label}`);
      if (wrong >= 0) problems.push(`row ${wrong} reads ${JSON.stringify(seen.rowTexts[wrong])}`);
      written[name] = html;
      if (name === "meltea-node" && "meltea-native" in written && html !== written["meltea-native"]) problems.push("bytes differ from the native Meltea server's");
      reference ??= seen;
      if (seen.text !== reference.text) problems.push(`text differs from ${renderers[0]}`);
      if (seen.digest !== reference.digest) problems.push(`normalised DOM differs from ${renderers[0]}`);
      const p95 = (values) => [...values].sort((a, b) => a - b)[Math.max(0, Math.ceil(values.length * 0.95) - 1)];
      const cell = {
        median: median(samples),
        p95: p95(samples),
        sent: median(sent),
        sentP95: p95(sent),
        perSecond: 1000 / median(sent),
        bytes: Buffer.byteLength(html),
        samples,
        problems,
      };
      results.ssr[count][name] = cell;
      log(`  string ${cell.median.toFixed(3)} ms (p95 ${cell.p95.toFixed(3)}), UTF-8 bytes ${cell.sent.toFixed(3)} ms (p95 ${cell.sentP95.toFixed(3)}), ${cell.perSecond.toFixed(0)}/s, ${cell.bytes} bytes${problems.length ? "  WRONG: " + problems.join("; ") : ""}`);
    }
  }
};

const page = (count, html) => {
  const data = `<script type="application/json" id="model">${JSON.stringify(rowsOf(count)).replaceAll("<", "\\u003c")}</script>`;
  return (template) => {
    if (!template.includes("<!--app-->") || !template.includes("<!--data-->")) throw new Error("template lost its placeholders");
    return template.replace("<!--data-->", () => data).replace("<!--app-->", () => html);
  };
};

// Installed before any page script: a promise for the client's `window.__hydrated = true`, and the
// first row and row count the parser built, taken before deferred and module scripts run.
const INSTRUMENT = `(() => {
  let resolve;
  let value;
  const hydration = new Promise((done) => (resolve = done));
  Object.defineProperty(window, "__hydration", { value: hydration });
  Object.defineProperty(window, "__hydrated", { get: () => value, set: (next) => { value = next; resolve(); } });
  document.addEventListener("readystatechange", () => {
    if (document.readyState !== "interactive") return;
    const rows = document.querySelectorAll("table.test-data > tbody > tr");
    window.__served = { first: rows[0] ?? null, last: rows[rows.length - 1] ?? null, count: rows.length };
  });
})();`;

const attach = async (browser) => {
  const { targetId } = await browser.send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await browser.send("Target.attachToTarget", { targetId, flatten: true });
  const send = (method, params) => browser.send(method, params, sessionId);
  const problems = [];
  const listener = (message) => {
    if (message.sessionId !== sessionId) return;
    if (message.method === "Runtime.exceptionThrown")
      problems.push(message.params.exceptionDetails.exception?.description ?? message.params.exceptionDetails.text);
    if (message.method === "Runtime.consoleAPICalled" && ["error", "warning", "assert"].includes(message.params.type))
      problems.push(`console.${message.params.type}: ${message.params.args.map((arg) => arg.value ?? arg.description).join(" ")}`.slice(0, 400));
  };
  browser.listeners.add(listener);
  const on = (method) =>
    new Promise((done) => {
      const once = (message) => {
        if (message.sessionId === sessionId && message.method === method) {
          browser.listeners.delete(once);
          done(message.params);
        }
      };
      browser.listeners.add(once);
    });
  const evaluate = async (expression) => {
    const { result, exceptionDetails } = await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
    return result.value;
  };
  const close = async () => {
    browser.listeners.delete(listener);
    await browser.send("Target.closeTarget", { targetId });
  };
  return { send, on, evaluate, close, problems };
};

const traced = async (browser, act) => {
  const events = [];
  const listener = (message) => {
    if (message.method === "Tracing.dataCollected") events.push(...message.params.value);
  };
  browser.listeners.add(listener);
  await browser.send("Tracing.start", { traceConfig: { includedCategories: CATEGORIES.split(","), recordMode: "recordAsMuchAsPossible" }, transferMode: "ReportEvents" });
  try {
    await act();
  } finally {
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
  }
  return events;
};

const QUIET = 500;

const hydration = (events) => {
  const end = events.find((event) => event.name === "hydrate:end" && event.cat.includes("blink.user_timing"));
  if (!end) throw new Error("no hydrate:end mark in trace");
  const start = events
    .filter((event) => event.name === "navigationStart" && event.pid === end.pid && event.ts <= end.ts)
    .sort((a, b) => b.ts - a.ts)[0];
  if (!start) throw new Error("no navigationStart in trace");
  const main = events.filter((event) => event.pid === end.pid && event.tid === end.tid && event.ph === "X" && event.ts + (event.dur ?? 0) >= start.ts);
  const until = end.ts + QUIET * 1000;
  const outermost = main
    .filter((event) => TASK.has(event.name) && event.ts < until)
    .sort((a, b) => a.ts - b.ts || b.dur - a.dur)
    .reduce((kept, task) => (kept.length && task.ts < kept[kept.length - 1].ts + kept[kept.length - 1].dur ? kept : [...kept, task]), []);
  const pick = (names) => main.filter((event) => names.has(event.name));
  return {
    busy: covered(pick(TASK), start.ts, end.ts),
    script: covered(pick(new Set([...SCRIPT, "v8.evaluateModule", "v8.compileModule", "v8.compile"])), start.ts, end.ts),
    layout: covered(pick(STYLE), start.ts, end.ts),
    paint: covered(pick(PAINT), start.ts, end.ts),
    parse: covered(pick(new Set(["ParseHTML"])), start.ts, end.ts),
    tbt: outermost.reduce((sum, task) => sum + Math.max(0, task.dur / 1000 - 50), 0),
    longest: Math.max(0, ...outermost.map((task) => task.dur / 1000)),
  };
};

const measureHydration = async (browser, url, count, throttle) => {
  const page = await attach(browser);
  try {
    await page.send("Page.enable");
    await page.send("Runtime.enable");
    await page.send("Page.addScriptToEvaluateOnNewDocument", { source: INSTRUMENT });
    await page.send("Emulation.setCPUThrottlingRate", { rate: throttle });
    let marks = null;
    const events = await traced(browser, async () => {
      const loaded = page.on("Page.loadEventFired");
      await page.send("Page.navigate", { url });
      await loaded;
      await page.evaluate("window.__hydration");
      marks = await page.evaluate(`(() => {
        const start = performance.getEntriesByName("hydrate:start")[0].startTime;
        const end = performance.getEntriesByName("hydrate:end")[0].startTime;
        return { hydrate: end - start, ready: end };
      })()`);
      await page.evaluate(`new Promise((done) => setTimeout(done, ${QUIET}))`);
    });
    const timing = { ...hydration(events), ...marks };
    if (args.trace) writeFileSync(join(args.trace, `${new URL(url).pathname.split("/")[1]}-${count}-${throttle}x-${Date.now()}.json`), JSON.stringify({ traceEvents: events }));
    await page.evaluate(PAGE_HELPERS);
    const adopted = await page.evaluate(`(() => {
      const rows = __rows();
      return { count: rows.length, served: window.__served.count, first: rows[0] === window.__served.first, last: rows[rows.length - 1] === window.__served.last };
    })()`);
    const problems = [...page.problems];
    if (adopted.served !== count) problems.push(`server HTML had ${adopted.served} rows`);
    if (adopted.count !== count) problems.push(`${adopted.count} rows after hydration`);
    if (!adopted.first || !adopted.last) problems.push("rows were rebuilt, not adopted");
    const target = "table.test-data > tbody > tr:nth-of-type(2) > td:nth-of-type(2) > a";
    await page.evaluate("__frame()");
    const point = await page.evaluate(`__point(${JSON.stringify(target)})`);
    await page.evaluate("__frame()");
    const clickEvents = await traced(browser, async () => {
      await page.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
      await page.send("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
      await page.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
      await page.evaluate(`__until(() => __rows()[1].className === "danger", 10000)`);
      await page.evaluate("__frame()");
    });
    const click = analyse(clickEvents).busy;
    const state = await page.evaluate("__state()");
    if (state.count !== count) problems.push(`${state.count} rows after the click`);
    if (JSON.stringify(state.danger) !== "[1]") problems.push(`selected rows ${JSON.stringify(state.danger)} after the click`);
    if (state.ids.some((id, index) => id !== index + 1)) problems.push("ids out of order after the click");
    problems.push(...state.problems);
    return { ...timing, click, problems };
  } finally {
    await page.close();
  }
};

const hydrate = async (results) => {
  const parseHTML = await linkedom();
  for (const name of frameworks) {
    const template = readFileSync(join(dist, name, "bench/ssr", name, "index.html"), "utf8");
    for (const count of sizes) {
      const { html } = renderWith(CLIENTS[name].server, count, 0, 0);
      if (digestOf(parseHTML, html).rows !== count) throw new Error(`${CLIENTS[name].server} rendered the wrong rows`);
      writeFileSync(join(dist, name, "bench/ssr", name, `index-${count}.html`), page(count, html)(template));
    }
  }
  results.sizes = measureSizes(frameworks, dist);
  for (const name of frameworks) log(`bundle ${name}: ${(results.sizes[name].gzip / 1024).toFixed(1)} kB gzip (raw ${(results.sizes[name].raw / 1024).toFixed(1)} kB)`);
  const server = await serve(dist);
  const { port } = server.address();
  const browser = await launch();
  results.hydration = {};
  try {
    results.chrome = (await browser.send("Browser.getVersion")).product;
    for (const count of sizes)
      for (const throttle of throttles) {
        const key = `${count}@${throttle}x`;
        results.hydration[key] = {};
        const samples = Object.fromEntries(frameworks.map((name) => [name, []]));
        for (let index = 0; index < runs; index++)
          for (const name of frameworks)
            samples[name].push(await measureHydration(browser, `http://127.0.0.1:${port}/${name}/bench/ssr/${name}/index-${count}.html`, count, throttle));
        for (const name of frameworks) {
          const of = (field) => median(samples[name].map((sample) => sample[field]));
          const problems = samples[name].flatMap((sample) => sample.problems);
          const cell = Object.fromEntries(["busy", "script", "layout", "paint", "parse", "hydrate", "ready", "tbt", "longest", "click"].map((field) => [field, of(field)]));
          results.hydration[key][name] = { ...cell, problems: [...new Set(problems)], samples };
          log(`hydrate ${key.padEnd(10)} ${name.padEnd(7)} ${Object.entries(cell).map(([field, value]) => `${field} ${value.toFixed(1)}`).join("  ")}${problems.length ? "  WRONG: " + [...new Set(problems)].slice(0, 3).join("; ") : ""}`);
        }
      }
  } finally {
    browser.close();
    server.close();
  }
};

const report = (results) => {
  const lines = [];
  const fixed = (value, digits = 1) => value.toFixed(digits);
  if (results.ssr) {
    lines.push(`### Server rendering (${warmups} warmups, then ${sizes.map(iterationsFor).join(" / ")} renders; median (p95) ms)`, "");
    lines.push("string: the renderer's call that returns the HTML string; bytes: the same call plus `Buffer.from(html)`, the UTF-8 a server sends (V8 builds strings by concatenation as ropes, and flattening them is deferred until something reads them; the native OCaml string is already bytes). renders/s from the bytes median.", "");
    lines.push("| renderer | " + sizes.map((count) => `${count.toLocaleString("en")} rows: string | bytes | renders/s | HTML kB`).join(" | ") + " |");
    lines.push("|---|" + sizes.map(() => "---:|---:|---:|---:").join("|") + "|");
    for (const name of renderers)
      lines.push(
        `| ${RENDERERS[name].label} | ` +
          sizes
            .map((count) => {
              const cell = results.ssr[count][name];
              return `${fixed(cell.median, 2)} (${fixed(cell.p95, 2)}) | ${fixed(cell.sent, 2)} (${fixed(cell.sentP95, 2)})${cell.problems.length ? " WRONG" : ""} | ${fixed(cell.perSecond, 0)} | ${fixed(cell.bytes / 1024)}`;
            })
            .join(" | ") +
          " |",
      );
    lines.push("");
  }
  if (results.hydration) {
    lines.push(`### Hydration (Chrome ${results.chrome}, ${runs} fresh tabs per cell, medians)`, "");
    lines.push(
      "hydrate: wall ms of the hydration itself, between marks around reading the data and the hydrate call (React: to the commit's layout effect); ready: wall ms from navigation start to hydrated; busy: main-thread busy ms from navigation start to hydrated, and its script, style + layout, paint and HTML parse parts; TBT: Σ(task − 50 ms) of the main thread's tasks from navigation start to 500 ms after hydration; longest: the longest of those tasks; click: busy ms from the first click on a row label to the paint showing it selected.",
      "",
    );
    const fields = ["hydrate", "ready", "busy", "script", "layout", "paint", "parse", "tbt", "longest", "click"];
    lines.push(`| rows @ CPU | framework | ${fields.join(" | ")} |`);
    lines.push(`|---|---|${fields.map(() => "---:").join("|")}|`);
    for (const [key, cells] of Object.entries(results.hydration))
      for (const name of frameworks)
        lines.push(`| ${key} | ${name}${cells[name].problems.length ? " WRONG" : ""} | ${fields.map((field) => fixed(cells[name][field])).join(" | ")} |`);
    lines.push("", `| client bundle | ${frameworks.join(" | ")} |`, `|---|${frameworks.map(() => "---:").join("|")}|`);
    lines.push(`| JS, kB gzip -9 (raw) | ${frameworks.map((name) => `${fixed(results.sizes[name].gzip / 1024)} (${fixed(results.sizes[name].raw / 1024)})`).join(" | ")} |`);
    lines.push("");
  }
  const problems = [
    ...Object.entries(results.ssr ?? {}).flatMap(([count, cells]) => Object.entries(cells).filter(([, cell]) => cell.problems.length).map(([name, cell]) => `- ssr ${name} ${count}: ${cell.problems.join("; ")}`)),
    ...Object.entries(results.hydration ?? {}).flatMap(([key, cells]) => Object.entries(cells).filter(([, cell]) => cell.problems.length).map(([name, cell]) => `- hydration ${name} ${key}: ${cell.problems.slice(0, 3).join("; ")}`)),
  ];
  lines.push(problems.length ? ["Correctness problems:", ...problems].join("\n") : "Every render and every hydrated page passed the correctness checks.");
  return lines.join("\n");
};

const main = async () => {
  if (!args["no-build"]) await build();
  const results = { date: new Date().toISOString(), node: process.version, warmups, runs };
  if (suites.includes("ssr")) await ssr(results);
  if (suites.includes("hydration")) await hydrate(results);
  writeFileSync(args.out ?? join(here, "results.json"), JSON.stringify(results, null, 2));
  process.stdout.write(report(results) + "\n");
};

if (args.child) await child();
else await main();
