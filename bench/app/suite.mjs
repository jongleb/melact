import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { categories, items, matches, owners } from "./data.mjs";

const here = dirname(fileURLToPath(import.meta.url));

// One Reason source built twice (reason-react on React 18, Melact), one JSX source built twice.
const BUILDS = {
  "reason-react": { folder: "reason-react" },
  melact: { folder: "melact" },
  react: { folder: "react", own: {} },
  "react-compiler": { folder: "react", own: { REACT_COMPILER: "1" } },
};

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

const APP_HELPERS = `
window.__summary = () => {
  const all = (selector) => Array.from(document.querySelectorAll(selector));
  const ids = (selector) => all(selector).map((element) => Number(element.querySelector(".id").textContent));
  const rows = all("ul.rows > li");
  const broken = rows.filter((row) => {
    const expanded = row.classList.contains("expanded");
    return expanded !== (row.querySelector(":scope > .details") !== null) || row.querySelector(".toggle").textContent !== (expanded ? "-" : "+");
  }).length;
  return {
    mounted: document.querySelector(".app") !== null,
    tab: document.querySelector(".tab.active")?.textContent ?? null,
    query: document.querySelector("#search")?.value ?? null,
    shown: document.querySelector("#shown")?.textContent ?? null,
    badge: document.querySelector("#badge")?.textContent ?? null,
    rows: ids("ul.rows > li"),
    expanded: ids("ul.rows > li.expanded"),
    broken,
    selected: ids("li.selected, .card.selected"),
    cards: ids(".card"),
    stats: all("table.stats tr").map((row) => Array.from(row.cells, (cell) => cell.textContent).join(" ")),
  };
};
window.__digest = () => {
  const normal = (node) => {
    const attributes = Array.from(node.attributes)
      .filter((attribute) => !(node.tagName === "INPUT" && attribute.name === "value"))
      .map((attribute) => attribute.name === "style" ? "style=" + node.style.cssText : attribute.name + "=" + attribute.value)
      .sort()
      .join(" ");
    const children = [];
    let text = "";
    for (const child of node.childNodes) {
      if (child.nodeType === 3) text += child.data;
      else if (child.nodeType === 1) {
        if (text) children.push(JSON.stringify(text));
        text = "";
        children.push(normal(child));
      }
    }
    if (text) children.push(JSON.stringify(text));
    return "<" + node.tagName.toLowerCase() + " " + attributes + ">" + children.join("") + "</>";
  };
  const markup = normal(document.getElementById("root"));
  let hash = 0x811c9dc5;
  for (let index = 0; index < markup.length; index++) hash = Math.imul(hash ^ markup.charCodeAt(index), 16777619) >>> 0;
  return { hash: hash.toString(16), length: markup.length, head: markup.slice(0, 2000) };
};
window.__poll = () => { console.timeStamp("__poll"); return __summary(); };
`;

const TABS = { list: "List", board: "Board", stats: "Stats" };

const initial = () => ({ mounted: false, tab: "list", query: "", selected: null, notifications: 0, bulk: "collapsed", folds: new Map() });

const visibleOf = (model) => items.filter(matches(model.query));

const remount = (model) => {
  const folds = new Map();
  if (model.mounted && model.tab === "list")
    for (const item of visibleOf(model)) folds.set(item.id, model.folds.get(item.id) ?? model.bulk);
  return { ...model, folds };
};

const expected = (model) => {
  if (!model.mounted) return { mounted: false, tab: null, query: null, shown: null, badge: null, rows: [], expanded: [], broken: 0, selected: [], cards: [], stats: [] };
  const visible = visibleOf(model);
  const list = model.tab === "list";
  const board = model.tab === "board";
  return {
    mounted: true,
    tab: TABS[model.tab],
    query: model.query,
    shown: `${visible.length} shown`,
    badge: String(model.notifications),
    rows: list ? visible.map((item) => item.id) : [],
    expanded: list ? visible.filter((item) => model.folds.get(item.id) === "expanded").map((item) => item.id) : [],
    broken: 0,
    selected: (list || board) && visible.some((item) => item.id === model.selected) ? [model.selected] : [],
    cards: board ? categories.flatMap((category) => visible.filter((item) => item.category === category).map((item) => item.id)) : [],
    stats: model.tab === "stats"
      ? owners.map((owner) => {
          const mine = visible.filter((item) => item.owner === owner);
          return `${owner} ${mine.length} ${mine.reduce((sum, item) => sum + item.points, 0)}`;
        })
      : [],
  };
};

const rowAt = (model, n) => visibleOf(model)[n - 1].id;

// Every action is a real input sent over CDP and the change it makes to the model.
const action = {
  mount: { click: "#mount", start: "click", apply: (model) => remount({ ...initial(), mounted: true }) },
  unmount: { click: "#unmount", start: "click", apply: () => initial() },
  tab: (tab) => ({ click: `#tab-${tab}`, start: "click", apply: (model) => remount({ ...model, folds: tab === model.tab ? model.folds : new Map(), tab }) }),
  focus: { click: "#search", start: "click", apply: (model) => model },
  key: (char) => ({ key: char, start: "keydown", apply: (model) => remount({ ...model, query: model.query + char }) }),
  clear: { click: "#clear-search", start: "click", apply: (model) => remount({ ...model, query: "" }) },
  bulk: (fold) => ({
    click: fold === "expanded" ? "#expand-all" : "#collapse-all",
    start: "click",
    apply: (model) => ({ ...model, bulk: fold, folds: new Map([...model.folds.keys()].map((id) => [id, fold])) }),
  }),
  toggle: (n) => ({
    click: `ul.rows > li:nth-of-type(${n}) .toggle`,
    start: "click",
    apply: (model) => {
      const id = rowAt(model, n);
      return { ...model, folds: new Map(model.folds).set(id, model.folds.get(id) === "expanded" ? "collapsed" : "expanded") };
    },
  }),
  select: (n) => ({ click: `ul.rows > li:nth-of-type(${n}) a.title`, start: "click", apply: (model) => ({ ...model, selected: rowAt(model, n) }) }),
  notify: { click: "#notify", start: "click", apply: (model) => ({ ...model, notifications: model.notifications + 1 }) },
};

const QUERY = "orang";

const times = (count, make) => Array.from({ length: count }, (_, index) => make(index)).flat();

const operations = (W) => [
  { name: "mount", detail: "mount the app with 1,000 rows", warmup: times(W, () => [action.mount, action.unmount]), steps: [action.mount] },
  { name: "tab list → board", detail: "1,000 rows → 1,000 cards", warmup: [action.mount, ...times(W, () => [action.tab("board"), action.tab("list")])], steps: [action.tab("board")] },
  { name: "tab board → list", detail: "1,000 cards → 1,000 rows", warmup: [action.mount, ...times(W, () => [action.tab("board"), action.tab("list")]), action.tab("board")], steps: [action.tab("list")] },
  { name: "tab list → stats", detail: "1,000 rows → 8 totals", warmup: [action.mount, ...times(W, () => [action.tab("stats"), action.tab("list")])], steps: [action.tab("stats")] },
  { name: "tab stats → list", detail: "8 totals → 1,000 rows", warmup: [action.mount, ...times(W, () => [action.tab("stats"), action.tab("list")]), action.tab("stats")], steps: [action.tab("list")] },
  {
    name: "type a character",
    detail: `type "${QUERY}" into search, one keystroke per sample: 1,000 → 91 rows`,
    warmup: [action.mount, action.focus, ...times(W, () => [...[...QUERY].map(action.key), action.clear, action.focus])],
    steps: [...QUERY].map(action.key),
  },
  { name: "clear search", detail: "91 → 1,000 rows", warmup: [action.mount, action.focus, ...times(W, () => [...[...QUERY].map(action.key), action.clear, action.focus]), ...[...QUERY].map(action.key)], steps: [action.clear] },
  { name: "expand all", detail: "expand 1,000 rows", warmup: [action.mount, ...times(W, () => [action.bulk("expanded"), action.bulk("collapsed")])], steps: [action.bulk("expanded")] },
  { name: "collapse all", detail: "collapse 1,000 rows", warmup: [action.mount, ...times(W, () => [action.bulk("expanded"), action.bulk("collapsed")]), action.bulk("expanded")], steps: [action.bulk("collapsed")] },
  { name: "toggle one row", detail: "expand one row's local state", warmup: [action.mount, ...times(W, (index) => [action.toggle(index + 2)])], steps: [action.toggle(1)] },
  { name: "select row", detail: "highlight one of 1,000 rows from the parent", warmup: [action.mount, ...times(W, (index) => [action.select(index + 5)])], steps: [action.select(2)] },
  { name: "notify", detail: "bump a badge unrelated to the list", warmup: [action.mount, ...times(W, () => [action.notify])], steps: [action.notify] },
];

const KEY_CODES = Object.fromEntries([..."abcdefghijklmnopqrstuvwxyz"].map((char) => [char, { code: `Key${char.toUpperCase()}`, windowsVirtualKeyCode: char.toUpperCase().charCodeAt(0) }]));

const send = async (page, step) => {
  if (step.key !== undefined) {
    const { code, windowsVirtualKeyCode } = KEY_CODES[step.key];
    await page.send("Input.dispatchKeyEvent", { type: "keyDown", key: step.key, code, windowsVirtualKeyCode, text: step.key, unmodifiedText: step.key });
    await page.send("Input.dispatchKeyEvent", { type: "keyUp", key: step.key, code, windowsVirtualKeyCode });
    return;
  }
  const point = await page.evaluate(`__point(${JSON.stringify(step.click)})`);
  if (point === null) throw new Error("no element " + step.click);
  await page.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
  await page.send("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await page.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
};

const differences = (found, wanted) =>
  Object.keys(wanted)
    .filter((key) => JSON.stringify(found[key]) !== JSON.stringify(wanted[key]))
    .map((key) => `${key}: expected ${JSON.stringify(wanted[key]).slice(0, 120)}, found ${JSON.stringify(found[key]).slice(0, 120)}`);

const settle = async (page, wanted, first, timeout = 20000) => {
  await sleep(first);
  const start = Date.now();
  for (;;) {
    const found = await page.evaluate(`__poll()`);
    const wrong = differences(found, wanted);
    if (!wrong.length) return [];
    if (Date.now() - start > timeout) return wrong;
    await sleep(25);
  }
};

export const run = async ({ args, log, repo, launch, openPage, serve, measureSizes, covered, median, CATEGORIES, SCRIPT, STYLE, PAINT, TASK }) => {
  const profiling = Boolean(args.profile);
  const runs = Number(args.runs ?? 7);
  const throttle = Number(args.throttle ?? 4);
  const warmups = Number(args.warmups ?? 5);
  const names = (args.frameworks ?? Object.keys(BUILDS).join(",")).split(",");
  const only = args.ops ? args.ops.split(",") : null;
  const dist = join(here, profiling ? "_dist-profile" : "_dist");
  const output = args.out ?? join(here, profiling ? "profile.json" : "results.json");

  const build = async () => {
    log("dune build ./bench/app");
    const dune = spawnSync("opam", ["exec", "--", "dune", "build", "./bench/app"], { cwd: repo, stdio: "inherit" });
    if (dune.status !== 0) throw new Error("dune build failed");
    const { build: viteBuild } = await import(join(repo, "node_modules/vite/dist/node/index.js"));
    for (const name of names) {
      log("vite build", name);
      const { folder, own } = BUILDS[name];
      const outDir = join(dist, name);
      if (own) {
        const built = spawnSync(
          process.execPath,
          [join(here, folder, "node_modules/vite/bin/vite.js"), "build", "--config", join(here, folder, "vite.config.mjs"), "--outDir", outDir],
          { cwd: repo, stdio: "inherit", env: { ...process.env, ...own, ...(profiling ? { BENCH_PROFILE: "1" } : {}) } },
        );
        if (built.status !== 0) throw new Error(`vite build ${name} failed`);
        continue;
      }
      await viteBuild({
        configFile: join(repo, "vite.config.js"),
        root: repo,
        base: "./",
        logLevel: "silent",
        build: { outDir, emptyOutDir: true, minify: profiling ? false : "esbuild", rollupOptions: { input: join(here, folder, "index.html") } },
      });
    }
  };

  const analyse = (unsorted, type, cutoff) => {
    const events = [...unsorted].sort((a, b) => a.ts - b.ts);
    const input = events.find((event) => event.name === "EventDispatch" && event.args?.data?.type === type);
    if (!input) throw new Error(`no ${type} in trace`);
    const stop = (event) => event.ts + (event.dur ?? 0);
    const main = events.filter((event) => event.pid === input.pid && event.tid === input.tid && event.ph === "X" && stop(event) >= input.ts);
    const stamps = events.filter((event) => event.name === "TimeStamp" && event.pid === input.pid && event.ts > input.ts).map((event) => event.ts);
    const last = stamps.filter((ts) => ts <= cutoff).at(-1) ?? Infinity;
    const pollTasks = main.filter((event) => TASK.has(event.name) && stamps.some((ts) => ts >= event.ts && ts <= stop(event)));
    const inPoll = (event) => pollTasks.some((task) => event.ts >= task.ts && event.ts <= stop(task));
    const own = main.filter((event) => event.ts < last && !inPoll(event));
    const lastScript = Math.max(...own.filter((event) => SCRIPT.has(event.name)).map(stop));
    const paints = own.filter((event) => event.name === "Paint" && event.ts >= input.ts);
    const paintEnd = (paint) => {
      const commit = own.find((event) => event.name === "Commit" && event.ts >= paint.ts);
      return Math.max(stop(paint), commit ? stop(commit) : 0);
    };
    const finalPaint = paints.find((event) => event.ts >= lastScript) ?? paints.at(-1);
    const end = Math.max(finalPaint ? paintEnd(finalPaint) : 0, lastScript);
    const pick = (set) => own.filter((event) => set.has(event.name));
    return {
      busy: covered(pick(TASK), input.ts, end),
      firstPaint: paints.length ? covered(pick(TASK), input.ts, paintEnd(paints[0])) : null,
      wall: (end - input.ts) / 1000,
      script: covered(pick(SCRIPT), input.ts, end),
      style: covered(pick(STYLE), input.ts, end),
      paint: covered(pick(PAINT), input.ts, end),
      gc: covered(own.filter((event) => /^(MajorGC|MinorGC|V8\.GC_)/.test(event.name)), input.ts, end),
      polls: covered(pollTasks, input.ts, end),
    };
  };

  const prepare = async (page, operation) => {
    await page.evaluate(APP_HELPERS);
    let model = initial();
    for (const step of operation.warmup) {
      await send(page, step);
      model = step.apply(model);
      const wrong = await settle(page, expected(model), 0);
      if (wrong.length) throw new Error(`warmup of ${operation.name}: ${wrong.join("; ")}`);
    }
    await page.evaluate(`__frame()`);
    await page.evaluate(`__frame()`);
    return model;
  };

  const traced = async (browser, page, step, wanted) => {
    await page.evaluate(`window.__renders = {}`);
    await page.send("Emulation.setCPUThrottlingRate", { rate: throttle });
    const events = [];
    const listener = (message) => {
      if (message.method === "Tracing.dataCollected") events.push(...message.params.value);
    };
    browser.listeners.add(listener);
    await browser.send("Tracing.start", { traceConfig: { includedCategories: CATEGORIES.split(","), recordMode: "recordAsMuchAsPossible" }, transferMode: "ReportEvents" });
    await send(page, step);
    const wrong = await settle(page, wanted, 150);
    await page.evaluate(`console.timeStamp("__poll")`);
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
    const stamps = events.filter((event) => event.name === "TimeStamp").map((event) => event.ts).sort((a, b) => a - b);
    const cutoff = wrong.length ? Infinity : stamps.at(-2) ?? stamps.at(-1);
    return { timing: analyse(events, step.start, cutoff), wrong };
  };

  const profiled = async (page, step, wanted) => {
    await page.evaluate(`window.__renders = {}`);
    await page.send("Profiler.enable");
    await page.send("Profiler.setSamplingInterval", { interval: 50 });
    await page.send("Emulation.setCPUThrottlingRate", { rate: throttle });
    await page.send("Profiler.start");
    await send(page, step);
    const wrong = await settle(page, wanted, 150);
    const { profile: data } = await page.send("Profiler.stop");
    await page.send("Emulation.setCPUThrottlingRate", { rate: 1 });
    const self = new Map();
    const nodes = new Map(data.nodes.map((node) => [node.id, node]));
    const parents = new Map(data.nodes.flatMap((node) => (node.children ?? []).map((child) => [child, node])));
    const name = (frame) => `${frame.functionName || "(anonymous)"} ${frame.url.split("/").pop()}:${frame.lineNumber + 1}`;
    data.samples.forEach((id, index) => {
      const frame = nodes.get(id).callFrame;
      if (["(idle)", "(program)", "(root)"].includes(frame.functionName)) return;
      if (frame.url === "" && !frame.functionName.startsWith("(")) return;
      if (/__poll|__summary/.test(frame.functionName)) return;
      const parent = parents.get(id)?.callFrame;
      const key = args.callers && parent ? `${name(frame)} ← ${name(parent)}` : name(frame);
      self.set(key, (self.get(key) ?? 0) + data.timeDeltas[index] / 1000);
    });
    return { self, wrong };
  };

  const sample = async (browser, url, operation) => {
    const page = await openPage(browser, url, "#mount");
    try {
      let model = await prepare(page, operation);
      const steps = [];
      for (const step of operation.steps) {
        model = step.apply(model);
        const measured = profiling ? await profiled(page, step, expected(model)) : await traced(browser, page, step, expected(model));
        const renders = await page.evaluate(`window.__renders`);
        steps.push({ ...measured, renders });
      }
      const digest = await page.evaluate(`__digest()`);
      return { steps, digest, problems: [...steps.flatMap((step) => step.wrong), ...page.exceptions] };
    } finally {
      await page.close();
    }
  };

  const memory = async (browser, url) => {
    const page = await openPage(browser, url, "#mount");
    try {
      await page.evaluate(APP_HELPERS);
      const heap = async () => {
        await page.evaluate(`__frame()`);
        await page.send("HeapProfiler.collectGarbage");
        await page.send("HeapProfiler.collectGarbage");
        return (await page.send("Runtime.getHeapUsage")).usedSize / 1048576;
      };
      await page.send("HeapProfiler.enable");
      const ready = await heap();
      await send(page, action.mount);
      const wrong = await settle(page, expected(action.mount.apply(initial())), 0);
      const mounted = await heap();
      return { ready, mounted, problems: [...wrong, ...page.exceptions] };
    } finally {
      await page.close();
    }
  };

  if (!args["no-build"]) await build();
  const sizes = measureSizes(names, dist);
  const server = await serve(dist);
  const { port } = server.address();
  const urlOf = (name) => `http://127.0.0.1:${port}/${name}/bench/app/${BUILDS[name].folder}/index.html`;
  const results = { date: new Date().toISOString(), chrome: "", runs, throttle, sizes, cpu: {}, memory: {}, problems: [] };
  const browser = await launch();
  try {
    results.chrome = (await browser.send("Browser.getVersion")).product;
    for (const operation of operations(warmups).filter((operation) => !only || only.includes(operation.name))) {
      const samples = Object.fromEntries(names.map((name) => [name, []]));
      const digests = new Map();
      for (let round = 0; round < runs; round++)
        for (const name of names) {
          const result = await sample(browser, urlOf(name), operation);
          if (result.problems.length) results.problems.push({ framework: name, operation: operation.name, round, problems: result.problems });
          digests.set(name, result.digest);
          samples[name].push(...result.steps);
        }
      const hashes = new Set([...digests.values()].map((digest) => digest.hash));
      if (hashes.size > 1) {
        results.problems.push({ framework: "all", operation: operation.name, problems: [`the four pages differ: ${[...digests].map(([name, digest]) => `${name} ${digest.hash}/${digest.length}`).join(", ")}`] });
        results.digests = { ...results.digests, [operation.name]: Object.fromEntries([...digests].map(([name, digest]) => [name, digest.head])) };
      }
      results.cpu[operation.name] = { detail: operation.detail };
      for (const name of names) {
        const renders = {};
        for (const step of samples[name]) for (const [component, count] of Object.entries(step.renders)) renders[component] = (renders[component] ?? 0) + count / samples[name].length;
        if (profiling) {
          const self = new Map();
          for (const step of samples[name]) for (const [key, time] of step.self) self.set(key, (self.get(key) ?? 0) + time / samples[name].length);
          const total = [...self.values()].reduce((sum, time) => sum + time, 0);
          const top = [...self.entries()].sort((a, b) => b[1] - a[1]).slice(0, Number(args.top ?? 15));
          results.cpu[operation.name][name] = { total, top, renders };
          log(`\n${operation.name} / ${name}: ${total.toFixed(2)} ms of samples per step; renders ${JSON.stringify(renders)}`);
          for (const [key, time] of top) log(`  ${time.toFixed(2).padStart(7)} ms  ${key}`);
          continue;
        }
        const timings = samples[name].map((step) => step.timing);
        const of = (key) => median(timings.map((timing) => timing[key]));
        const totals = timings.map((timing) => timing.busy);
        results.cpu[operation.name][name] = {
          median: median(totals),
          firstPaint: median(timings.map((timing) => timing.firstPaint ?? timing.busy)),
          wall: of("wall"),
          script: of("script"),
          style: of("style"),
          paint: of("paint"),
          gc: of("gc"),
          min: Math.min(...totals),
          max: Math.max(...totals),
          samples: totals,
          renders,
        };
        log(`${operation.name.padEnd(18)} ${name.padEnd(15)} ${median(totals).toFixed(1).padStart(7)} ms  [${Math.min(...totals).toFixed(1)}–${Math.max(...totals).toFixed(1)}]  script ${of("script").toFixed(1)}  style+layout ${of("style").toFixed(1)}  paint ${of("paint").toFixed(1)}  gc ${of("gc").toFixed(1)}  renders ${Object.values(renders).reduce((sum, count) => sum + count, 0).toFixed(0)}`);
      }
    }
    if (!profiling && (!only || only.includes("memory")))
      for (const name of names) {
        const samples = [];
        for (let round = 0; round < Math.min(runs, 5); round++) samples.push(await memory(browser, urlOf(name)));
        for (const sample of samples) if (sample.problems.length) results.problems.push({ framework: name, operation: "memory", problems: sample.problems });
        results.memory[name] = { ready: median(samples.map((sample) => sample.ready)), mounted: median(samples.map((sample) => sample.mounted)) };
        log(`memory ${name.padEnd(15)} ready ${results.memory[name].ready.toFixed(2)} MB, mounted ${results.memory[name].mounted.toFixed(2)} MB`);
      }
  } finally {
    browser.close();
    server.close();
  }
  writeFileSync(output, JSON.stringify(results, null, 2));
  if (!profiling) process.stdout.write(report(results, names) + "\n");
  else if (results.problems.length) log(JSON.stringify(results.problems, null, 2));
};

const report = (results, names) => {
  const lines = [];
  lines.push(`Chrome ${results.chrome}, ${results.throttle}× CPU slowdown, ${results.runs} fresh page loads per cell. Median main-thread busy ms from the input event to the paint after the last script it caused (script / style+layout / paint / gc in parentheses), ×ratio to React 18.`);
  lines.push("");
  lines.push(`| operation | ${names.join(" | ")} |`);
  lines.push(`|---|${names.map(() => "---:").join("|")}|`);
  for (const [operation, cells] of Object.entries(results.cpu)) {
    const base = cells.react?.median;
    lines.push(
      `| ${operation} <br><sub>${cells.detail}</sub> | ${names
        .map((name) => {
          const cell = cells[name];
          if (!cell) return "";
          const ratio = base && name !== "react" ? ` ×${(cell.median / base).toFixed(2)}` : "";
          return `**${cell.median.toFixed(1)}**${ratio}<br><sub>${cell.script.toFixed(1)} / ${cell.style.toFixed(1)} / ${cell.paint.toFixed(1)} / ${cell.gc.toFixed(1)}</sub>`;
        })
        .join(" | ")} |`,
    );
  }
  lines.push("");
  lines.push(`| component renders per operation | ${names.join(" | ")} |`);
  lines.push(`|---|${names.map(() => "---:").join("|")}|`);
  for (const [operation, cells] of Object.entries(results.cpu))
    lines.push(`| ${operation} | ${names.map((name) => Object.values(cells[name]?.renders ?? {}).reduce((sum, count) => sum + count, 0).toFixed(0)).join(" | ")} |`);
  lines.push("");
  lines.push(`| size and memory | ${names.join(" | ")} |`);
  lines.push(`|---|${names.map(() => "---:").join("|")}|`);
  lines.push(`| JS bundle, kB (gzip -9) | ${names.map((name) => results.sizes[name] ? `${(results.sizes[name].gzip / 1024).toFixed(1)} (raw ${(results.sizes[name].raw / 1024).toFixed(1)})` : "").join(" | ")} |`);
  if (Object.keys(results.memory).length) {
    lines.push(`| heap before mount, MB | ${names.map((name) => results.memory[name]?.ready.toFixed(2) ?? "").join(" | ")} |`);
    lines.push(`| heap after mount, MB | ${names.map((name) => results.memory[name]?.mounted.toFixed(2) ?? "").join(" | ")} |`);
  }
  lines.push("");
  if (results.problems.length) {
    lines.push("Correctness problems:");
    for (const problem of results.problems) lines.push(`- ${problem.framework} / ${problem.operation}: ${problem.problems.slice(0, 3).join("; ")}`);
  } else lines.push("Every run passed the correctness checks, and the four pages were identical after every operation.");
  return lines.join("\n");
};
