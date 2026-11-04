# Changelog

- Milestone 1: `melact.view` (templates with holes, hole patcher, keyed reconcile, delegated events), `melact.program` sandbox, hand-written counter example, 26 vitest + jsdom tests.
- Milestone 2: component instances and hooks (`Hook` keys, `Component`, `Context`, microtask flush, effects), `React`, `ReactDOM.Client`; the same test suite passes against reason-react with React 18 and against melact.
- Milestone 3: `melact-ppx` for Reason, OCaml `[@JSX]` and mlx: one template per JSX tree, hook keys per call site, `[@react.component]` and signatures; expect tests in `test/ppx`.
- Runtime trimming: no `Printf`, `Hashtbl` or `Map` in the bundle; keyed lookup by sorted keys. The counter app went from 23.4 kB to 10.2 kB gzip.
- A runtime made of parts: every kind of child carries its own mount and patch code, every hole its own `put_*`, and the component scheduler is installed by the first component. Unused parts drop out of the bundle: the counter app is 5.7 kB gzip with Meltea and 7.5 kB with Melact.
- Compiled walks: the compiler writes out the `firstChild`/`nextSibling` walk to every hole and picks HTML or SVG parsing, so the runtime keeps no paths and no tag table. The counter app is 4.2 kB gzip with Meltea and 5.9 kB with Melact.
