// Builds every app in bench/classics twice (reason-react on React 18.3, and Melact), drives both
// through the app's scenario in headless Chromium, and compares main-thread time, layouts, style
// recalcs, heap and the DOM after every step. Writes results.json and RESULTS.md next to itself.
//
//   node bench/classics/run.mjs [--apps=todomvc,grid] [--runs=5] [--cpu=1,4] [--no-build] [--headed]
import { spawnSync } from "node:child_process";
import { createServer } from "node:http";
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "../..");
const dist = join(here, "_dist");
const playwrightPath = process.env.PLAYWRIGHT ?? "/Users/gleb/Home/wg/node_modules/playwright/index.mjs";

const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const [, key, value] = arg.match(/^--([^=]+)(?:=(.*))?$/s);
    return [key, value ?? "true"];
  }),
);
const runs = Number(args.runs ?? 5);
const rates = (args.cpu ?? "1,4").split(",").map(Number);
const frameworks = ["react", "melact"];
const log = (...parts) => process.stderr.write(parts.join(" ") + "\n");

const allApps = readdirSync(here)
  .filter((name) => existsSync(join(here, name, "scenario.mjs")) && existsSync(join(here, name, "app.mlx")))
  .sort();
const apps = args.apps ? args.apps.split(",") : allApps;

const build = async () => {
  if (args["no-build"] !== "true") {
    log("dune build ./bench/classics");
    const dune = spawnSync(join(here, "build.sh"), apps, { cwd: repo, stdio: "inherit" });
    if (dune.status !== 0) log("dune build failed; apps that built are still measured");
  }
  const esbuild = await import(join(repo, "node_modules/esbuild/lib/main.js"));
  const melangeOutput = {
    name: "melange-output",
    setup(build) {
      build.onResolve({ filter: /^[^./]/ }, ({ path, importer }) => {
        const output = importer.match(/^(.*\/_build\/default\/.*?\/output)\//);
        if (!output) return null;
        const candidate = join(output[1], "node_modules", path);
        return existsSync(candidate) ? { path: candidate } : null;
      });
    },
  };
  const shared = readFileSync(join(here, "style.css"), "utf8");
  const built = [];
  for (const app of apps) {
    const own = join(here, app, "style.css");
    const style = shared + (existsSync(own) ? readFileSync(own, "utf8") : "");
    mkdirSync(join(dist, app), { recursive: true });
    let ok = true;
    for (const framework of frameworks) {
      const entry = join(repo, "_build/default/bench/classics", app, framework, "output/bench/classics", app, framework, "app.mjs");
      if (!existsSync(entry)) {
        log(`missing ${entry}`);
        ok = false;
        continue;
      }
      await esbuild.build({
        entryPoints: [entry],
        bundle: true,
        format: "esm",
        minify: true,
        outfile: join(dist, app, `${framework}.js`),
        define: { "process.env.NODE_ENV": '"production"' },
        plugins: [melangeOutput],
        logLevel: "error",
      });
      writeFileSync(
        join(dist, app, `${framework}.html`),
        `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${app} ${framework}</title><style>${style}</style></head>` +
          `<body><div id="bench-controls"><button id="mount">Mount</button><button id="unmount">Unmount</button></div>` +
          `<div id="root"></div><div id="portal"></div><script type="module" src="./${framework}.js"></script></body></html>`,
      );
    }
    if (ok) built.push(app);
  }
  return built;
};

const serve = () =>
  new Promise((done) => {
    const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };
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

const median = (values) => {
  const sorted = values.filter((value) => value !== undefined).sort((a, b) => a - b);
  if (sorted.length === 0) return undefined;
  const middle = sorted.length >> 1;
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
};

const firstDifference = (left, right) => {
  let index = 0;
  while (index < left.length && left[index] === right[index]) index++;
  return {
    at: index,
    react: left.slice(Math.max(0, index - 120), index + 200),
    melact: right.slice(Math.max(0, index - 120), index + 200),
  };
};

const helpers = readFileSync(join(here, "helpers.js"), "utf8");

const runOnce = async (browser, origin, app, framework, steps, rate, keepDom) => {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  await context.addInitScript(helpers);
  const page = await context.newPage();
  page.setDefaultTimeout(600000);
  const console = [];
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") console.push(`${message.type()}: ${message.text()}`);
  });
  page.on("pageerror", (error) => console.push(`pageerror: ${error.stack ?? error.message}`));
  const cdp = await context.newCDPSession(page);
  await cdp.send("Performance.enable", { timeDomain: "threadTicks" });
  await cdp.send("Emulation.setCPUThrottlingRate", { rate });
  await page.goto(`${origin}/${app}/${framework}.html`, { waitUntil: "load" });
  const metrics = async () => {
    const { metrics } = await cdp.send("Performance.getMetrics");
    return Object.fromEntries(metrics.map(({ name, value }) => [name, value]));
  };
  const all = [{ name: "mount", run: () => __h.click("#mount") }, ...steps];
  const results = [];
  let crash;
  for (const step of all) {
    await page.evaluate(() => __h.settle());
    const before = await metrics();
    let settled;
    try {
      await page.evaluate(step.run);
      settled = await page.evaluate(() => __h.settle());
    } catch (error) {
      crash = { step: step.name, error: String(error.message ?? error).slice(0, 2000) };
      break;
    }
    const after = await metrics();
    const { html, raw } = await page.evaluate(() => ({
      html: __h.snapshot(document.getElementById("root")) + "\n<!--portal-->\n" + __h.snapshot(document.getElementById("portal")),
      raw: document.getElementById("root").innerHTML + document.getElementById("portal").innerHTML,
    }));
    const errors = await page.evaluate(() => __h.errors.splice(0));
    results.push({
      step: step.name,
      task: (after.TaskDuration - before.TaskDuration) * 1000,
      script: (after.ScriptDuration - before.ScriptDuration) * 1000,
      layoutTime: (after.LayoutDuration - before.LayoutDuration) * 1000,
      styleTime: (after.RecalcStyleDuration - before.RecalcStyleDuration) * 1000,
      layouts: after.LayoutCount - before.LayoutCount,
      styles: after.RecalcStyleCount - before.RecalcStyleCount,
      rounds: settled.rounds,
      settled: settled.settled,
      hash: createHash("sha1").update(html).digest("hex"),
      rawHash: createHash("sha1").update(raw).digest("hex"),
      html: keepDom ? html : undefined,
      errors,
    });
    if (errors.length) {
      crash = { step: step.name, error: errors.join("\n").slice(0, 2000) };
      break;
    }
  }
  let heap;
  if (!crash) {
    await cdp.send("HeapProfiler.enable");
    await cdp.send("HeapProfiler.collectGarbage");
    await cdp.send("HeapProfiler.collectGarbage");
    heap = (await cdp.send("Runtime.getHeapUsage")).usedSize;
    const before = await metrics();
    await page.evaluate(() => __h.click("#unmount"));
    await page.evaluate(() => __h.settle());
    const after = await metrics();
    results.push({
      step: "unmount",
      task: (after.TaskDuration - before.TaskDuration) * 1000,
      layouts: after.LayoutCount - before.LayoutCount,
      styles: after.RecalcStyleCount - before.RecalcStyleCount,
      hash: "",
    });
  }
  await context.close();
  return { results, heap, crash, console: console.slice(0, 20) };
};

const measureApp = async (browser, origin, app) => {
  const { default: steps } = await import(pathToFileURL(join(here, app, "scenario.mjs")).href);
  const report = { app, rates: {} };
  for (const rate of rates) {
    const samples = { react: [], melact: [] };
    for (let run = 0; run < runs; run++)
      for (const framework of run % 2 ? [...frameworks].reverse() : frameworks) {
        log(`${app} ${rate}x run ${run + 1}/${runs} ${framework}`);
        samples[framework].push(await runOnce(browser, origin, app, framework, steps, rate, run === 0));
      }
    const names = ["mount", ...steps.map((step) => step.name), "unmount"];
    const rows = names.map((name) => {
      const row = { step: name };
      for (const framework of frameworks) {
        const found = samples[framework].map((sample) => sample.results.find((result) => result.step === name)).filter(Boolean);
        row[framework] = {
          task: median(found.map((result) => result.task)),
          script: median(found.map((result) => result.script)),
          layoutTime: median(found.map((result) => result.layoutTime)),
          styleTime: median(found.map((result) => result.styleTime)),
          layouts: median(found.map((result) => result.layouts)),
          styles: median(found.map((result) => result.styles)),
          rounds: median(found.map((result) => result.rounds)),
          unsettled: found.filter((result) => result.settled === false).length,
          samples: found.map((result) => Math.round(result.task * 10) / 10),
        };
      }
      const react = samples.react[0].results.find((result) => result.step === name);
      const melact = samples.melact[0].results.find((result) => result.step === name);
      if (react && melact && name !== "unmount") {
        row.identical = react.hash === melact.hash;
        row.rawIdentical = react.rawHash === melact.rawHash;
        if (!row.identical) {
          row.difference = firstDifference(react.html, melact.html);
          const dir = join(dist, app, "dom");
          mkdirSync(dir, { recursive: true });
          const file = `${rate}x-${names.indexOf(name)}`;
          writeFileSync(join(dir, `${file}-react.html`), react.html);
          writeFileSync(join(dir, `${file}-melact.html`), melact.html);
        }
      }
      const hashes = (framework) => new Set(samples[framework].map((sample) => sample.results.find((result) => result.step === name)?.hash));
      row.deterministic = frameworks.every((framework) => hashes(framework).size <= 1);
      return row;
    });
    report.rates[rate] = {
      rows,
      heap: Object.fromEntries(frameworks.map((framework) => [framework, median(samples[framework].map((sample) => sample.heap))])),
      crashes: Object.fromEntries(
        frameworks.map((framework) => [framework, samples[framework].map((sample) => sample.crash).filter(Boolean).slice(0, 1)]),
      ),
      console: Object.fromEntries(frameworks.map((framework) => [framework, samples[framework][0].console])),
    };
  }
  return report;
};

const format = (value, digits = 1) => (value === undefined || Number.isNaN(value) ? "–" : value.toFixed(digits));

const writeMarkdown = (all) => {
  const lines = [
    "# Classic apps: reason-react on React 18.3 vs Melact",
    "",
    "Generated by `node bench/classics/run.mjs`. Each app is one `app.mlx`, compiled against reason-react",
    "(React 18.3.1, production build) and against Melact, bundled by esbuild, and driven through its",
    "`scenario.mjs` in headless Chromium (Playwright). Per step: median over the runs of the main-thread",
    "busy time (CDP `TaskDuration` delta, from before the step until the page has settled: no DOM mutation",
    "during two animation frames and a task), and of the `LayoutCount` and `RecalcStyleCount` deltas.",
    "Ratio is Melact / React; above 1 Melact is slower. DOM: the root's and the portal container's",
    "markup after the step (attributes sorted, form fields' `value`/`checked` added), React's first run",
    "against Melact's first run.",
    "",
  ];
  const losses = [];
  const counts = [];
  const differences = [];
  const crashes = [];
  const rawOnly = new Set();
  for (const report of Object.values(all).sort((a, b) => a.app.localeCompare(b.app))) {
    for (const [rate, data] of Object.entries(report.rates)) {
      for (const row of data.rows) {
        const ratio = row.melact.task / row.react.task;
        if (ratio > 1.05) losses.push({ app: report.app, rate, row, ratio });
        if (row.melact.layouts > row.react.layouts || row.melact.styles > row.react.styles) counts.push({ app: report.app, rate, row });
        if (row.identical === false && rate === String(rates[0])) differences.push({ app: report.app, row });
        if (row.identical === true && row.rawIdentical === false) rawOnly.add(report.app);
      }
      for (const framework of frameworks)
        for (const crash of data.crashes[framework]) crashes.push({ app: report.app, rate, framework, crash });
    }
  }
  lines.push("## Where Melact is slower (ratio > 1.05)", "");
  lines.push("| app | cpu | step | React ms | Melact ms | ratio | layouts R/M | styles R/M |", "|---|---|---|---:|---:|---:|---:|---:|");
  for (const { app, rate, row, ratio } of losses.sort((a, b) => b.ratio - a.ratio))
    lines.push(
      `| ${app} | ${rate}x | ${row.step} | ${format(row.react.task)} | ${format(row.melact.task)} | ${format(ratio, 2)} | ${format(row.react.layouts, 0)}/${format(row.melact.layouts, 0)} | ${format(row.react.styles, 0)}/${format(row.melact.styles, 0)} |`,
    );
  lines.push("", "## Where Melact lays out or recalculates style more often", "");
  lines.push("| app | cpu | step | layouts R/M | styles R/M | React ms | Melact ms |", "|---|---|---|---:|---:|---:|---:|");
  for (const { app, rate, row } of counts)
    lines.push(
      `| ${app} | ${rate}x | ${row.step} | ${format(row.react.layouts, 0)}/${format(row.melact.layouts, 0)} | ${format(row.react.styles, 0)}/${format(row.melact.styles, 0)} | ${format(row.react.task)} | ${format(row.melact.task)} |`,
    );
  lines.push("", "## DOM differences and crashes", "");
  if (!differences.length && !crashes.length) lines.push("None.");
  for (const { app, row } of differences)
    lines.push(
      `- **${app}**, after \`${row.step}\`: first difference at character ${row.difference.at}`,
      "  - React: `" + row.difference.react.replace(/`/g, "'").replace(/\n/g, " ") + "`",
      "  - Melact: `" + row.difference.melact.replace(/`/g, "'").replace(/\n/g, " ") + "`",
    );
  for (const { app, rate, framework, crash } of crashes)
    lines.push(`- **${app}** (${rate}x, ${framework}) crashed at \`${crash.step}\`: \`${crash.error.split("\n")[0].replace(/`/g, "'")}\``);
  if (rawOnly.size)
    lines.push(
      "",
      "Raw `innerHTML` differs only in attribute order (React writes props in the order of reason-react's " +
        "`domProps`, Melact in source order) in: " +
        [...rawOnly].sort().join(", ") +
        ". The comparison above sorts attributes and adds each form field's `value` and `checked` properties.",
    );
  for (const rate of rates) {
    lines.push("", `## All steps, CPU ${rate}x`, "");
    lines.push(
      "| app | step | React ms | Melact ms | ratio | layouts R/M | style recalcs R/M | DOM identical |",
      "|---|---|---:|---:|---:|---:|---:|---|",
    );
    for (const report of Object.values(all).sort((a, b) => a.app.localeCompare(b.app))) {
      const data = report.rates[rate];
      if (!data) continue;
      for (const row of data.rows)
        lines.push(
          `| ${report.app} | ${row.step} | ${format(row.react.task)} | ${format(row.melact.task)} | ${format(row.melact.task / row.react.task, 2)} | ${format(row.react.layouts, 0)}/${format(row.melact.layouts, 0)} | ${format(row.react.styles, 0)}/${format(row.melact.styles, 0)} | ${row.identical === undefined ? "–" : row.identical ? "yes" : "**no**"} |`,
        );
    }
  }
  lines.push("", "## JS heap after the scenario (MB, after two forced GCs)", "");
  lines.push(`| app | ${rates.map((rate) => `React ${rate}x | Melact ${rate}x`).join(" | ")} |`, `|---|${rates.map(() => "---:|---:").join("|")}|`);
  for (const report of Object.values(all).sort((a, b) => a.app.localeCompare(b.app)))
    lines.push(
      `| ${report.app} | ${rates
        .map((rate) => {
          const heap = report.rates[rate]?.heap ?? {};
          return `${format(heap.react / 1048576, 2)} | ${format(heap.melact / 1048576, 2)}`;
        })
        .join(" | ")} |`,
    );
  writeFileSync(args.out ? resultsPath.replace(/\.json$/, ".md") : join(here, "RESULTS.md"), lines.join("\n") + "\n");
};

const resultsPath = resolve(here, args.out ?? "results.json");
const previous = existsSync(resultsPath) ? JSON.parse(readFileSync(resultsPath, "utf8")) : {};
if (args["markdown-only"] === "true") {
  writeMarkdown(previous);
  process.exit(0);
}
const built = await build();
const { chromium } = await import(playwrightPath);
const browser = await chromium.launch({ headless: args.headed !== "true", args: ["--disable-background-timer-throttling", "--disable-renderer-backgrounding"] });
const server = await serve();
const origin = `http://127.0.0.1:${server.address().port}`;
try {
  for (const app of built) {
    const report = await measureApp(browser, origin, app);
    previous[app] = report;
    writeFileSync(resultsPath, JSON.stringify(previous, null, 1));
    writeMarkdown(previous);
    for (const row of report.rates[rates[0]].rows)
      log(
        `  ${row.step.padEnd(28)} R ${format(row.react.task).padStart(8)}  M ${format(row.melact.task).padStart(8)}  x${format(row.melact.task / row.react.task, 2)}  L ${row.react.layouts}/${row.melact.layouts}  S ${row.react.styles}/${row.melact.styles}  ${row.identical === false ? "DOM DIFFERS" : ""}`,
      );
  }
} finally {
  await browser.close();
  server.close();
}
