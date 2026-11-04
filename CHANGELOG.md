# Changelog

- Milestone 1: `melact.view` (templates with holes, hole patcher, keyed reconcile, delegated events), `melact.program` sandbox, hand-written counter example, 26 vitest + jsdom tests.
- Milestone 2: component instances and hooks (`Hook` keys, `Component`, `Context`, microtask flush, effects), `React`, `ReactDOM.Client`; the same test suite passes against reason-react with React 18 and against melact.
- Milestone 3: `melact-ppx` for Reason, OCaml `[@JSX]` and mlx: one template per JSX tree, hook keys per call site, `[@react.component]` and signatures; expect tests in `test/ppx`.
- Runtime trimming: no `Printf`, `Hashtbl` or `Map` in the bundle; keyed lookup by sorted keys. The counter app went from 23.4 kB to 10.2 kB gzip.
- A runtime made of parts: every kind of child carries its own mount and patch code, every hole its own `put_*`, and the component scheduler is installed by the first component. Unused parts drop out of the bundle: the counter app is 5.7 kB gzip with Meltea and 7.5 kB with Melact.
- Compiled walks: the compiler writes out the `firstChild`/`nextSibling` walk to every hole and picks HTML or SVG parsing, so the runtime keeps no paths and no tag table. The counter app is 4.2 kB gzip with Meltea and 5.9 kB with Melact.
- Direct writes: the compiled walk makes typed holes once per clone and the refresh writes them with `set_text`, `set_attr` and friends; no binding table, no indices. The counter app is 4.0 kB gzip with Meltea and 5.7 kB with Melact.
- TodoMVC in Meltea (`examples/todomvc`): routing, editing, `localStorage`, 8.7 kB gzip, checked by a model-based law over real DOM events. Meltea gains `Sub.hash`, `Cmd.focus` and `Cmd.port`; subscriptions are typed by their source. Controlled inputs: `value` and `checked` are put back after input when the state did not take it, as in React, for both Meltea and Melact.
