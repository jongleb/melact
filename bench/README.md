# Keyed benchmark

A local reproduction of the keyed CPU, memory and size tests of
[js-framework-benchmark](https://github.com/krausest/js-framework-benchmark), for Meltea and
Melact against hand-written vanilla JS and React 18.

| app | what it is |
|---|---|
| [`vanilla/`](vanilla/main.js) | hand-written keyed DOM code in the style of the benchmark's `vanillajs-keyed`: one cloned `<tr>` template, event delegation on `tbody`, manual keyed operations |
| [`meltea/`](meltea/main.mlx) | the Elm architecture: model, messages, pure `update`, a `view` with a `row` function and a keyed `Html.list` of `<tr key=…>` |
| [`melact/`](melact/main.mlx) | reason-react style: `useReducer` in an `App` component, a `React.memo` `Row` component |
| [`react/`](react/main.js) | React 18.3 with hooks, like the benchmark's `react-hooks`: `useReducer`, `memo` rows, `createElement` |

All four render the same markup and share [`style.css`](style.css), a small inline stand-in for the
benchmark's Bootstrap sheet (the harness downloads nothing).

## Run

```console
$ DYLD_LIBRARY_PATH=/opt/homebrew/Cellar/simdjson/4.6.4/lib node bench/run.mjs
```

(On a machine whose `node` starts without it, drop `DYLD_LIBRARY_PATH`.) The harness builds the two
OCaml apps with `dune build ./bench`, bundles all four for production with Vite into `bench/_dist`,
serves them from a local HTTP server, drives headless Chrome over the DevTools protocol, prints a
Markdown table and writes every sample to `bench/results.json`.

Options: `--runs=N` (page loads per operation and app, default 10), `--memory-runs=N` (default 5),
`--frameworks=vanilla,meltea` , `--ops="select row,swap rows,memory"`, `--no-build` (reuse
`bench/_dist`), `--out=file.json`, `--trace=dir` (keep the trace of each measured click),
`--probe=expression` (log a page expression after each measured operation), `--before=expression`
(evaluate one before the measured click), `CHROME=path`.

`--profile` swaps the trace for the V8 sampling profiler (50 µs) on unminified bundles in
`bench/_dist-profile` and prints, per operation and app, the functions with the most self time
averaged over the runs (`--top=N`, default 15); results go to `bench/profile.json`.

## Method

- Every sample is a fresh tab: load, the benchmark's warmups for that operation, then one measured
  click, sent as real mouse input (`Input.dispatchMouseEvent`).
- The measured click is traced (`devtools.timeline`). The time is the renderer main thread's busy
  time from the start of the `click` dispatch to the end of the first `Paint` and its `Commit`
  after it. Idle time spent waiting for the next vsync is left out: headless Chrome begins frames
  on its own clock, which adds 0–16 ms of noise to a plain click-to-paint wall time (the JSON keeps
  that wall time too). Script, style and layout, and paint times are the parts of it; the JSON and
  the log also give main-thread V8 GC time and background (concurrent) marking time inside the
  window, because a major GC started by the app's allocations slows Blink's style and layout.
- CPU slowdown as in the benchmark: 4× for partial update, select, swap and clear, 2× for remove.
- After every measured click the page is checked: row count, every id in order, every label
  (three words from the benchmark's lists followed by the right number of ` !!!`), the markup of
  every row, and which rows have `class="danger"`. A fast but wrong result is reported, not
  counted silently.
- Memory: `HeapProfiler.collectGarbage` twice, then `Runtime.getHeapUsage`, after load, after
  creating 1,000 rows, and after five more create/clear cycles.
- Size: the gzip (-9) size of all JS in the production bundle.

# The official js-framework-benchmark

[`official/run.sh`](official/run.sh) runs the real
[js-framework-benchmark](https://github.com/krausest/js-framework-benchmark) with Meltea and Melact
added as two more keyed frameworks, the way [dartea](https://github.com/jongleb/dartea) does it. It
clones the benchmark at a pinned commit into `~/.cache/melact-jfb` (`JFB=dir` moves it), copies the
Melange output of `bench/meltea` and `bench/melact` into `frameworks/keyed/meltea` and
`frameworks/keyed/melact` ([`official/meltea`](official/meltea), [`official/melact`](official/melact):
`package.json`, lockfile, `index.html`; bundled by esbuild and terser into `dist/main.js`), builds
the other frameworks from the benchmark's own folders, and runs the official runner in headless
Chrome. Every other implementation is the benchmark's own; React 18 is the benchmark's
`react-hooks` with `react@18.3.1` pinned (`react-hooks-18`).

```console
$ bench/official/run.sh                       # build, bench, results
$ FRAMEWORKS="meltea melact" bench/official/run.sh build bench results
```

Steps can be named (`build`, `bench`, `results`). `FRAMEWORKS` (default: vanillajs meltea melact
react-hooks react-hooks-18 svelte vue-vapor solid inferno elm ivi), `BENCHMARKS` (id prefixes),
`PORT` (default 8080), `CHROME`, `MAX_LOAD` (default 3: before each framework it waits, up to 30
minutes, for the 1-minute load average to drop below it). `bench` first runs the benchmark's
`isKeyed` check on every framework. `results` builds the benchmark's results page, copies the raw
results to [`official/results`](official/results) and saves a screenshot,
[`official/result.png`](official/result.png).

It measures what the official table measures: the nine CPU operations (median of total duration,
15 runs, 25 for select row, with the official CPU slowdowns), memory after load, after 1,000 rows
and after five create/clear cycles, and the size of the implementation files (uncompressed and
brotli) with first paint. Startup is not in the benchmark's default set at this commit.

Latest run: Apple M5, Chrome 151.0.7922.138 headless, November 8, 2026, benchmark commit `fa510a7`.
This is my machine, not the official published table. Factors are against the fastest
implementation in each row, as on the results page.

| | Meltea | Vue Vapor 3.6 | Melact | vanilla | Inferno | Svelte 5 | Solid | ivi | Elm | React 19 | React 18 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| CPU, weighted geometric mean | **1.03** | 1.04 | **1.06** | 1.06 | 1.15 | 1.16 | 1.29 | 1.45 | 1.49 | 1.51 | 1.51 |
| memory, geometric mean | **1.26** | 1.50 | **1.40** | 1.00 | 1.27 | 1.34 | 1.23 | 1.13 | 1.52 | 2.46 | 2.37 |
| size and first paint, geometric mean | **2.67** | 3.92 | **4.35** | 1.06 | 2.87 | 2.46 | 1.30 | 1.32 | 2.71 | 11.47 | 8.73 |
| JS, brotli, kB | 10.6 | 18.7 | 18.0 | 2.5 | 9.3 | 9.7 | 4.5 | 4.0 | 10.4 | 51.4 | 39.9 |

The sizes of this run are of an esbuild-only bundle; the terser pass now in the build makes the
gzip of both about 10% smaller. Other work shared the machine: all numbers come from one pass over
the eleven frameworks, each started at a 1-minute load between 2.3 and 3 except vanilla (4.5); a
later rerun of four of them under heavier load was discarded.

# App benchmark

js-framework-benchmark is one list component. [`app/`](app) measures what one state change costs
across nested components with hooks: a small task app with 1,000 items, three tabs (a list of rows,
a board of cards grouped by status, per-owner totals), a search field that filters as you type, rows
with local `useState` (expanded or not, synced from "Expand all" / "Collapse all" by a `useEffect`),
a child `Details` and `Tags` per row, a selection driven from the parent, a theme context, and a
badge unrelated to the list. Every component counts its renders (`window.__renders`).

| build | source |
|---|---|
| `reason-react` | [`app/src/app.mlx`](app/src/app.mlx) with reason-react on React 18.3 ([`app/reason-react/dune`](app/reason-react/dune)) |
| `melact` | the same file with Melact: the dune file differs in two words ([`app/melact/dune`](app/melact/dune)) |
| `react` | [`app/react/src/app.jsx`](app/react/src/app.jsx), the same app in idiomatic JSX on React 18.3 |
| `react-compiler` | the same JSX with `babel-plugin-react-compiler` 1.0 (target 18), which compiles all 15 components |

The Reason source is written as ordinary reason-react code: inline closures and style records in
props, arrays built in render, `useMemo` for the filter and the totals only.

```console
$ (cd bench/app/react && npm install)
$ DYLD_LIBRARY_PATH=/opt/homebrew/Cellar/simdjson/4.6.4/lib node bench/run.mjs --suite=app
```

It reuses the harness above (browser, trace phases, medians, `--profile`, `--top`, `--no-build`,
`--frameworks`, `--ops`, `--out`) and adds `--throttle=N` (CPU slowdown for every operation,
default 4), `--warmups=N` (default 5), `--runs=N` (default 7) and, with `--profile`, `--callers`
(self time split by calling function). Bundles go to `bench/app/_dist`, samples to
`bench/app/results.json`.

Operations, each on a fresh page after its warmups: mount; switch tab list → board, board → list,
list → stats, stats → list; type `orang` into search one real key event at a time
(`Input.dispatchKeyEvent`, one sample per keystroke, 1,000 → 91 rows); clear the search; expand all;
collapse all; toggle one row; select a row; bump the badge. The time is main-thread busy time from
the input event to the paint after the last script it caused, so effects that run after the first
paint and the renders they cause are counted. Waiting for the page to settle is done by polls
marked in the trace with `console.timeStamp`, and their tasks are left out.

After every measured step the page must match a model of the app built from
[`app/data.mjs`](app/data.mjs): active tab, the field's value, the count shown, the badge, the ids of
the rows in order, which rows are expanded (with their details and toggle in agreement), the
selection, the cards and the totals. After each operation the normalised DOM of the four builds
(tags, sorted attributes, text) must also be identical. The report gives the phases, the component
renders per operation, the gzip size of the bundle, and the heap before and after mount.

# Server rendering and hydration

[`ssr/`](ssr) renders one page on the server and hydrates it in the browser, in every framework: a
header, a counter and a table of N rows (1,000 and 10,000) shaped like js-framework-benchmark's
(id, label link that selects, remove icon, `danger` on the selected row), with the same labels
everywhere (`adjectives[i % 25] colours[i % 11] nouns[i % 13]`).

| build | server | client |
|---|---|---|
| [`meltea/`](ssr/meltea/page.mlx) | `Program.render` from `meltea.server` with `meltea-ppx -server`, natively ([`server/`](ssr/meltea/server/server.ml)) and under Melange in Node ([`node/`](ssr/meltea/node/ssr.ml)) | `Program.sandbox ~start:Program.hydrate`, `meltea-ppx -hydratable` |
| [`melact/`](ssr/melact/page.mlx) | `ReactDOMServer.renderToString` from `melact.server` with `melact-ppx -server`, natively ([`server/`](ssr/melact/server/server.ml), `melact.server.native`) and under Melange in Node ([`node/`](ssr/melact/node/ssr.mlx)) | `ReactDOM.Client.hydrateRoot`, `melact-ppx -hydratable` |
| [`react/`](ssr/react/src/App.jsx) | React 18.3 `renderToString`, production | `hydrateRoot` |
| [`svelte/`](ssr/svelte/src/App.svelte) | Svelte 5 `render` from `svelte/server`, compiled for the server by its own Vite | `hydrate` |

```console
$ (cd bench/ssr && npm install) && (cd bench/ssr/react && npm install) && (cd bench/ssr/svelte && npm install)
$ DYLD_LIBRARY_PATH=/opt/homebrew/Cellar/simdjson/4.6.4/lib node bench/ssr/run.mjs
```

Options: `--suites=ssr,hydration`, `--rows=1000,10000`, `--warmups=N` (default 20),
`--iterations=N` (default 200 renders for 1,000 rows, 50 for 10,000), `--renderers=meltea-native,…`,
`--frameworks=meltea,melact,react,svelte`, `--runs=N` (fresh tabs per hydration cell, default 10),
`--throttles=1,4`, `--no-build`, `--out=file.json`, `--trace=dir`. Samples go to
`bench/ssr/results.json`.

- Server rendering: every Node renderer runs in its own fresh Node process (`NODE_ENV=production`),
  the native one in its own executable; warmups, then the median and p95 of each call, both as the
  string the renderer returns and with `Buffer.from(html)` added, since V8 defers flattening a string
  built by concatenation until something reads it. Every page's HTML is parsed and must hold the N
  rows with the right ids and labels, the same text, and the same normalised DOM (tags, attributes
  with an empty `class` counted as none, texts) as the first renderer's; the Melange builds of the
  Meltea and Melact servers must write their native ones' bytes.
- Hydration: each client is bundled for production with Vite; the page is its own server's HTML
  plus the rows as a `<script type="application/json">`. Every sample is a fresh tab, traced from
  navigation to 500 ms after the client sets `window.__hydrated` (after the hydrate call returns;
  React's from a layout effect of its first commit). It reports the marks around the hydration, the
  main thread's busy time from navigation start to hydrated with its script, layout and paint parts,
  total blocking time, then the busy time of a first real click on a row label until the paint that
  shows the row selected. Every page must keep the rows the parser built (the first and last row
  elements are the same objects after hydration), and show exactly that row selected after the click.

# Resuming a served page

[`resume/`](resume/run.mjs) compares `Program.hydrate` with `Program.resume` on a served TodoMVC of
1,000 and 5,000 rows: a native server ([`resume/server`](resume/server/server.ml)) writes the page,
the capture script and the model, and the client takes it over at startup (`?hydrate`) or at the
first input (`?resume`). For each page load it reports the main thread's busy time and Total
Blocking Time from navigation to the first click, then presses a row's checkbox for 80 ms and reports
the longest task after it and the time from the press to the paint after the click.

```console
$ DYLD_LIBRARY_PATH=/opt/homebrew/Cellar/simdjson/4.6.4/lib node bench/resume/run.mjs --runs=9
```

Options: `--runs=N`, `--sizes=1000,5000`, `--rates=1,4` (CPU throttling), `--press=ms`,
`--variants=hydrate,resume`, `--no-build`, `--breakdown` (main-thread time per trace event).

## Melact against an earlier Melact

`node bench/classics/versus.mjs --base=<commit>` builds every app of the corpus at `<commit>` (in a
temporary worktree) and at the working tree, runs them app by app in turn and flags each step where
Melact does more layouts or style recalculations than before, or where its time against React (the
control, built from the same app) grew by more than 15%. It exits with 1 when a step is flagged.
`--apps=eventtable,trace`, `--runs`, `--cpu` and `--threshold` narrow it.

## The working tree against a base commit, in time

`node bench/ab.mjs --base=<commit>` builds the base in a temporary worktree and runs
`bench/run.mjs` on the base and on the working tree in turns (base, head, base, head…, 3 rounds of
8 runs by default), with vanilla in every turn as the control, so that a loaded machine weighs on
both alike. It compares the median script time of every operation and exits with 1 when Meltea or
Melact got more than 8% slower on one beyond what vanilla moved. Run it before handing over any
change to the runtime or the compiler; the ratchet (`test/ratchet`) counts the DOM work, this
checks the time the JavaScript itself takes.
