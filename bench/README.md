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
