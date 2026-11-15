# Meltea: the road to Svelte

Where Meltea stands against Svelte 5, measured, and the steps that close the distance. Each step
is one piece of work: it lands on `main` with its laws, the guards of `CLAUDE.md` and a number that
went down.

## Where it stands (2026-11-14)

The official js-framework-benchmark (`bench/official`, medians in ms, sizes in kB):

| | create 1k | update 10th | select | swap | remove | clear | size gzip | memory ready |
|---|---|---|---|---|---|---|---|---|
| vanilla | 18.7 | 13.8 | 3.5 | 11.3 | 9.4 | 8.1 | 2.5 | 0.6 |
| **Meltea** | 19.1 | 10.6 | 3.3 | 12.7 | 9.7 | 7.9 | **10.6** | 0.7 |
| Svelte 5.42 | 20.0 | 13.2 | 5.0 | 13.7 | 10.7 | 9.5 | 9.7 | 0.6 |
| Solid 1.9 | 19.4 | 14.2 | 5.6 | 20.2 | 13.4 | 12.3 | 4.5 | 0.6 |
| Elm 0.19 | 25.8 | 16.0 | 5.9 | 16.8 | 14.1 | 12.7 | 10.4 | 0.6 |

Time is done: Meltea is at or below Svelte on every operation. What is not Svelte yet is the
runtime. A bundle is mostly runtime, and most of it is code the program never runs:

| bundle (esbuild, minified) | total | gzip | melhole `view` | `Program` | `events` | `curry` | the program's own code |
|---|---|---|---|---|---|---|---|
| `meltea/examples/counter` | 15.1 kB | 5.3 kB | 4.8 | 2.4 | 2.1 | 1.4 | 1.6 |
| `bench/meltea` | 33.4 kB | 11.7 kB | 13.7 | 2.4 | 2.1 | 1.4 | 6.9 |
| `meltea/examples/todomvc` | 72.9 kB | 22.6 kB | 18.6 | 2.6 | 2.4 | 1.5 | 15.6 |

Of `bench/meltea`'s `view`, the keyed loop `View.rows` is two thirds: one function that carries
selectors, projections, pieces, numbering, chunks and hydration whether a loop uses them or not.
A counter links the subscription machinery, hot reload, resumption and view transitions because
`Program.sandbox` names them. The six buttons of the benchmark, a local function called with
constants, are six content holes, each a nested template mounted through the generic child
protocol, where Svelte would have put them in the page's HTML.

## Targets

- `meltea/examples/counter` under 2 kB gzip; `bench/meltea` under 7 kB, below Svelte's 9.7.
- No operation of `bench/ab.mjs` slower than the base, no ratchet counter up.
- Every step keeps Meltea pure Elm: no hooks, no annotations the user must write.
- Work per message proportional to what the message changed, not to the size of the model or the
  view (see the deltas track below).

## The deltas track: update says what it did

A guard asks after the fact whether a value changed, and to answer it reads the old value and the
new one. In Meltea the answer is known before: the model changes only through `update`, and
`update` knows what it did. The compiler makes it say so, and the view does what the change implies
instead of checking.

### The guarantee

For a program that passes the typed check (its model is immutable, its view reads only the model,
its arguments and constants, its controlled elements are declared), the page after every draw is
`view model`, and no hole is checked after the fact, except on the element a browser event just
reached. What fails the check gets an alert and falls back to guards; nothing is ever silently
wrong.

The three ways the page could need a change that `update` did not report, and what closes each:

- **The browser changes the DOM** (typing, a checkbox, `<details>`, autofill), and `update` keeps
  the model as it was, as when it rejects a character. Neither a delta nor `===` sees it. Closed by
  controlled holes (`value`, `checked`, `open`): after an event on such an element, its DOM is
  compared with its hole once (`View.controlled_hole`, `restore_controlled` already do this). A
  value written without a handler gets an alert.
- **The view reads something besides the model**: `Js.Date.now`, `Js.Math.random`, a `ref`, an
  external. Guards miss it too. Typed, every read of the view is known: such a hole is evaluated on
  every draw, as today, with an alert that suggests moving the value into the model through a
  subscription.
- **The model is mutated in place**: `model.rows.(1) <- x; model`, a table or a JS object inside
  the model. Guards miss it too, since the reference is the same. Typed, a write in `update` to a
  value reachable from the model makes that field `Replaced` with an alert; a field of a type that
  can change elsewhere (abstract, from JS) is taken as changed on every message.

A delta is the compiler's reading of `update`, and a reading can be wrong where `===` looks at real
values. So: whatever is not recognised is `Replaced`, the path of today; laws compare every draw
with a fresh mount of the model, with mutants; and a development build audits every draw, running
the guarded path beside the delta and raising on any difference, with the message and the hole.

### Steps of the track

- **D1. Work counters.** Per message: `===` checks, items of collections read, view functions
  called, allocations of the draw. Deterministic, so they are the main measure (timing on this
  machine is noisy), with a law that work is proportional to the change on random programs.
- **D2. The typed graph.** Move `fields` and `slice` to the Typedtree: exact names (`Array.append`
  is `Stdlib.Array.append`), paths of nested fields (`editor.draft`), view and update functions with
  parameters inside the file, gates inside functions and rows. The untyped reading stays as the
  fallback.
- **D3. Changes derived from types.** From the type of the model: a record changes per field, an
  array or a list by an edit script (`Appended`, `Removed_at`, `Swapped`, `Set_at`, `Thinned`), a
  variant without payload by `Became (old, new)`, anything else by `Replaced`. `update` is rewritten
  to return the change beside the model; each recognised construct gives its edit.
- **D4. Loops and holes that read changes.** On bench/meltea: swap, remove, append and select
  without a pass over the rows (swap reads 2,002 old items today).
- **D5. Incremental `let`s.** `filter`, `map` and `length` of a collection follow its edits (they
  are linear), so TodoMVC's counts and filtered list do not recompute.
- **D6. A draw per message and tables of states.** For a message with a structured change, a draw
  that writes what it implies with no bits and no checks; a field with finitely many constants gets
  its DOM transitions computed at build time.

## Steps

### 1. A size ledger for Meltea

The size ratchet (`test/ratchet/sizes.mjs`) knows Melact's examples, not Meltea's. Add
`meltea/examples/counter`, `todomvc` and the served client, and a `--by-module` report (bytes per
module and per function in the minified bundle) so that every later step names the bytes it
removed. Nothing else moves; this is the instrument.

### 2. Program pays for what it is given

`Program.sandbox` and `element` link every way to start (mount, hydrate, resume, hot), the
subscription differ and view transitions. Make each a value that carries its own code, as the
children of melhole already do: `start` becomes a record of functions, subscriptions are linked
only by `element`, view transitions only by `Cmd.view_transition`. A counter links mount and the
draw loop.

### 3. Uncurried runtime

`curry.mjs` is 1.4 kB in every bundle: calls through closures whose arity Melange cannot see.
Mark the runtime's function-valued fields and arguments `[@u]` (the protocol of children already
is) and have `meltea-ppx` emit uncurried handlers and refreshes, until `Curry` leaves the bundle.

### 4. Loops built from the parts they use

`View.rows` becomes a skeleton plus parts the compiler passes only when the loop needs them:
selectors (only for `match selection with Selected chosen when chosen = id`), projections, pieces,
numbering, chunks, adoption of server HTML. Each part is a value with its own code, so a loop
over plain rows links the skeleton and the keyed moves. Laws: the existing loop laws run over
every combination of parts.

### 5. Mount-only bundles without hydration

`View.compiled` reaches `adopted`, the collecting medium and the cursor walk even when the program
only mounts. Route adoption through the `start` of step 2, so that a client that never hydrates
links none of it.

### 6. View helpers spliced into the page

A local or module-level function that returns a view, called with arguments the compiler can
see, is spliced into the caller's template: its static part joins the caller's HTML, its holes
become holes of the caller, guarded by the arguments they read. `(button "run" "Create 1,000
rows" Run)` becomes part of the page's markup, with one handler hole and no content hole. This
is Melact's "Spliced into the caller" for Meltea, without components. A law: a spliced and a
non-spliced build of random views show the same page after random messages.

### 7. Field gates through view functions

Elm programs split their view: `view_header model`, `view_footer model.items`. Today gates stop
at function boundaries. Read a view function's parameter the way the view's model is read, so
that the bits of the fields it reaches gate the hole that calls it, across modules through the
companions that already carry masks.

### 8. Child programs

The Elm pattern of nested modules: `Child.update` in a branch of the parent's `update`, and
`Html.map (fun m -> Child m) (Child.view model.child)` in its view. Compose the child's masks
under the parent's field, so that a message of one child gates the holes of that child only.

### 9. Templates per state and facts about collections

A field only ever set to constants (`filter = All | Active | Completed`, already found by
`Fields.lattice`) gets one template per value, switched without a diff. A recognised edit of a
collection in `update` (append, filter, swap of a copied array, point write) records a fact that
the compiled loop patches from in O(change) instead of scanning all rows
(`_research/compiler-maximum.md` has the prototype and its laws).

### 10. What Svelte gives authors

- Scoped styles: a style in an mlx file compiled at build time into class names private to the
  file and a CSS file beside the bundle, nothing at run time.
- Accessibility alerts, like `fanout`: an `<img>` without `alt`, a click handler on an element that
  cannot take focus, a keyed list whose `key` is constant.

### 11. Classic apps in Meltea

Port a handful of `bench/classics` apps (todomvc, kanban, spreadsheet, hackernews, datagrid) to
Meltea and to Svelte 5, driven by the same scenarios, so that time, layouts and size are measured
on real programs and not only on the keyed benchmark.

## Guards

Every step, before it is pushed: `opam exec -- dune build`, `dune test`, `dune build @runtest-js &&
npx vitest run`, `node bench/ab.mjs --base=origin/main --frameworks=meltea`, `RATCHET_SLOW=1 node
test/ratchet/lower.mjs` and `node test/ratchet/sizes.mjs`. A step that touches `melhole/` also runs
`node bench/ab.mjs` for both frameworks and `node bench/classics/versus.mjs`, since Melact shares it.
