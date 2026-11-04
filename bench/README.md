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
