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

  Done for items read: `Counters.watched` wraps a model's array in a proxy that counts every item
  the runtime reads (a law checks the count, and a mutant that stops counting fails it), and
  `test/ratchet/meltea/meltea_keyed.mlx` runs each operation of the keyed benchmark on 1,000 rows
  as its own ratchet run. The baseline, against what the change needs:

  | operation | DOM work | items read | needed |
  |---|---|---|---|
  | select row | 2 classes | 2 | 2 |
  | swap rows | 2 moves | 4,004 | 0 |
  | remove row | 1 removal | 2,000 | 0 |
  | partial update | 100 texts | 4,000 | 100 |
  | append rows | 1,000 insertions | 5,000 | 1,000 |
  | create rows | 1,000 insertions | 3,000 | 1,000 |
  | replace all rows | 1,000 + 1,000 | 5,126 | 1,000 |
  | clear rows | 1,000 removals | 0 | 0 |

  The facts of D3–D4 for arrays brought these to: swap 4, remove 0, partial update 200, append
  1,000, create 1,000 (see D4).
- **D2. The typed graph.** Move `fields` and `slice` to the Typedtree: exact names (`Array.append`
  is `Stdlib.Array.append`), paths of nested fields (`editor.draft`), view and update functions with
  parameters inside the file, gates inside functions and rows. The untyped reading stays as the
  fallback.
- **D3. Changes derived from types.** From the type of the model: a record changes per field, an
  array or a list by an edit script (`Appended`, `Removed_at`, `Swapped`, `Set_at`, `Thinned`), a
  variant without payload by `Became (old, new)`, anything else by `Replaced`. `update` is rewritten
  to return the change beside the model; each recognised construct gives its edit.
- **D4. Loops and holes that read changes.** On bench/meltea: swap, remove, append and select
  without a pass over the rows.

  Done for arrays. The typed pass of `meltea-ppx` (`ppx/meltea/facts.ml`) reads the Typedtree and,
  by exact paths (`Stdlib.Array.append`, not any `append`) and pure arguments (names, constants,
  immutable fields, arithmetic), wraps what it recognises in `Melhole_meltea.Delta.record`: an append, a
  cut of one block by two `Array.sub`, a `mapi` that writes one place or every n-th, and writes to
  a copied array that what follows only stores (an exchange of two items, or a rewrite of some).
  A fact lives in a `WeakMap` keyed by the new array and holds the old one weakly. `View.rows`
  asks `View.hinting` before it scans; linking `Delta` is what installs it, so a bundle whose code
  records nothing carries none of it. A fact turns into one of the loop's own arrangements:
  inserted, removed, two rows exchanged, or only these places renewed, their keys checked. What is
  not recognised, or does not check, takes the scans, which now make one pass that also collects
  the rows renewed in place. Laws (`test/facts`): random messages, after every draw the page is a
  fresh mount and every row whose key stays keeps its node; fixed scenarios of each fact followed
  by a draw that matches rows by key; the rows a recognised edit reads. 13 mutants, all caught.

  Next: a typed alert when the file cannot be typed (facts then silently stay off for the whole
  file), lists (`@`, `::`, `List.filter`), and the key check of renewed rows proved at build time
  (`{ row with label }` keeps the field the key reads), which brings partial update to 100.
- **D5. Incremental `let`s.** `filter`, `map` and `length` of a collection follow its edits (they
  are linear), so TodoMVC's counts and filtered list do not recompute.

  Measured first and put off (2026-11-17). Toggling one todo of TodoMVC in headless Chromium,
  sampled every 50 µs over 100 toggles: 0.36 ms of script per toggle with 1,000 todos, 1.10 ms
  with 5,000. The view's two `List.filter`s and its `List.length` take 0.12 ms of the 1.10 (0.02
  of the 0.36), and the loop that follows them still passes over every row, so following edits
  would save at most that until lists carry facts (D4). The largest part is the example's own
  persistence, `encode` of every todo and `localStorage.setItem` on every message (0.40 ms).
  Inside both, 0.19 ms in all is Melange's curried call (`_1`) of the callbacks given to
  `List.filter`, `List.map` and the JSON encoder.
- **D6. A draw per message and tables of states.** For a message with a structured change, a draw
  that writes what it implies with no bits and no checks; a field with finitely many constants gets
  its DOM transitions computed at build time.

  Measured first on the keyed benchmark (2026-11-16), against vanilla, Svelte 5 and Vue Vapor:
  Meltea's mean slowdown against vanilla is 1.06 (Svelte 1.15, Vapor 1.09), and its script time is
  within 0.1–0.6 ms of vanilla's on every operation, the rest being style, layout and paint. The
  checks and bits a per-message draw would remove are not where the time goes: three hand-edited
  bundles (a text node in the template for each text hole; no slot or check for a value fixed by
  the row's key; the row's data on its `<tr>` once) measured within noise. The heap was the gap:
  1,000 rows took 279 KB more than vanilla's, 112 KB of it Blink's attribute storage for a
  `class=""` written on every row that is not selected. So the first piece of tables of states:
  where every value a `className` can take is a literal, `meltea-ppx` turns the empty one into no
  attribute at build time (`None`), so an unselected row carries no attribute at all, the runtime
  is unchanged and the bundles shrink by a few bytes. What remains of the gap is V8's: the code the
  runtime compiles (79 KB), the row frames (48 KB), and the expandos of the two linked handlers of
  each row (20 KB, which only a change to the core's delegation would remove).

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

Measured on 2026-11-16, after Meltea got its own runtime: a client compiled without `-hydratable`
already links almost none of it (bench/meltea carries `browser_adopt`, a stub that raises, and
the `medium` indirection, about 250 B minified). The cost is in templates compiled `-hydratable`,
whose writers check what the server wrote (`served_*`) and which carry their adoption code: the
TodoMVC example's library was compiled so for its tests, which render it on the server and
hydrate it, though its app only mounts. The tests now compile their own copy hydratable and the
example's bundle went from 21,852 to 20,816 B gzipped (−1,036 B). So the flag belongs to the
module of the app that hydrates; what is left of this step is a template compiled `-hydratable`
that costs nothing in an app that mounts it.

### 6. View helpers spliced into the page

A local or module-level function that returns a view, called with arguments the compiler can
see, is spliced into the caller's template: its static part joins the caller's HTML, its holes
become holes of the caller, guarded by the arguments they read. `(button "run" "Create 1,000
rows" Run)` becomes part of the page's markup, with one handler hole and no content hole. This
is Melact's "Spliced into the caller" for Meltea, without components. A law: a spliced and a
non-spliced build of random views show the same page after random messages.

Done for local helpers (`ppx/meltea/splice.ml`, before the templates are compiled). A
`let f a b = <element …>` whose call is a child of an element, with every argument a constant, a
constructor or a name, is replaced there by its body with the arguments put in place, and a helper
with no call left is dropped. Since a view is pure, the place of a call does not matter, unlike
Melact's components, which splice only into the rows of a `map`. The check is conservative: a call
stays a call when a name the body reads, or the helper's own, is bound anywhere between the helper
and its calls, when an argument is a name the body binds, or when a module is opened in either. On
bench/meltea the six buttons join the page's template (11,125 → 11,038 B gzipped) and TodoMVC's
three filter links join the footer's (20,816 → 20,679 B); each spliced call is one template, one
content hole and one frame fewer. Laws (`test/meltea/splice_laws_test.mlx`): a view with helpers
spliced, and the same view with every call kept inside `Html.list`, show the same page after random
messages; a helper whose read name is bound again and a call whose argument the body binds are
there too, and dropping either check, or putting the arguments in the wrong places, breaks the law
or the build. Next: helpers at the top level of the module, and arguments that are expressions
(bound once by a `let` in the caller where the compiler can keep the hole guarded).

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


### 9a. The update graph, and the runtime it shows an app never needs

The typed file shows every path a change can take: a message, the branch of `update` it takes, the
fields that branch writes, the places in the view that read them, and the element the message came
from. Each consumer of that graph removes a piece of the runtime an app is proved never to reach,
so the runtime shrinks to what each app uses; script time is already within 0.1 to 0.6 ms of
vanilla's on the keyed benchmark, and the bytes are what is left.

First, loops whose source is the same value at every draw: a value bound at the top of a module,
or one of another module. Such a loop never has other items to compare, so `Fixed` (a typed pass)
calls `View.fixed` instead of `View.rows`: the build and the same-source path of `rows`, with no
keys, scans, facts or moves; nothing has to be proved about the value, since `rows` itself
compares nothing for a source that is the same. All three loops of spreadsheet are such, so its
bundle no longer holds `rows` or `Reconcile`: 29.5 kB gzip to 25.7 (Svelte's is 25.6). A law in
`test/facts/fixed_laws_test.mlx`: such a loop shows what the same loop over a value made in the
view shows after any messages, keeps its rows' nodes and never computes a key (four mutants: no
rewrite, any source taken as fixed, a change of outer values ignored, changed rows not refreshed).

Tried next, and put off (2026-11-17): loops whose source keeps its order. `View.ordered`, a copy of
`rows` that merges the new order with the old in one pass and moves a row it finds elsewhere (so
nodes are always kept, and a wrong proof costs moves only), and a typed pass that proves a source
is a model field the view filters and every value of it is filtered, mapped without touching what
the key reads, or added to at either end. Three things stood in the way. `Reconcile.plan` has three
callers (`rows`, `each` for rows given by a function, and `list` for keyed children built at run
time), and TodoMVC and kanban reach it through `each` and `list`, so `ordered` alone removes it from
no app; a shared core for `rows` and `ordered` cost every other app 126 bytes. Inlining a row
function into a compiled loop (`List.map (row editing) shown`) took `each` and `Reconcile` out of
the SSR client (1,022 bytes) but added 610 to TodoMVC, where compiled rows are larger than `each`,
and raised the ratchet's key counts. And a value the proof took as new because it does not name the
field can still come from it through the whole model (`reorder model`): new must mean that it reads
no model at all. The work is kept in a stash on the `meltea` worktree; the saving it aims at is
about 825 bytes gzip on TodoMVC.

Next consumers, each with a law and a size ratchet: fields bound to the input that writes them (the
field holds what the input shows, so no `restore_controlled`); programs with no commands or
subscriptions (no general loop in `Program`).
### 10. What Svelte gives authors

- Scoped styles: a style in an mlx file compiled at build time into class names private to the
  file and a CSS file beside the bundle, nothing at run time.
- Accessibility alerts, like `fanout`: an `<img>` without `alt`, a click handler on an element that
  cannot take focus, a keyed list whose `key` is constant.

### 11. Classic apps in Meltea

Port a handful of `bench/classics` apps (todomvc, kanban, spreadsheet, hackernews, datagrid) to
Meltea and to Svelte 5, driven by the same scenarios, so that time, layouts and size are measured
on real programs and not only on the keyed benchmark.

Started with TodoMVC (5,000 todos, 12 steps). `bench/classics/run.mjs --frameworks=<base>,<other>`
compares any two builds; Meltea's are `<app>/meltea/app.mlx` with `common/meltea/classic.ml`,
Svelte's `<app>/svelte/App.svelte` (idiomatic runes: `$state`, `$derived`, mutation in place),
compiled by esbuild with the Svelte 5.57.3 compiler. The DOM is identical to React's and to
Svelte's after every step. Results in `bench/classics/meltea/results.md` (against React) and
`svelte.md`: the geometric mean of Meltea's time is 0.71 of React's and 0.89 of Svelte's (1x;
0.72 and 0.93 at 4x), with the same layouts and style recalcs; the bundle is 14.4 kB gzip
(Svelte 23.2, React 50.2); the heap after the scenario is 1.73 MB (Svelte 1.53). Meltea is slower
than Svelte in `filter active` (1.28, 1.21 at 4x: about 1,650 of 5,000 rows leave the list),
`edit one todo` at 4x (1.13) and `toggle all again` at 4x (1.07).

`filter active` was not the rows: removing them took 2.6 ms in Meltea and 2.7 ms in Svelte. Half
of Meltea's 12 ms was the native `click` following the filter link's `href="#"`, a fragment
navigation that lays out the page, because a Meltea handler could not cancel the default action;
Svelte's and React's do. Now the element says it: a link to `#` goes nowhere, so `meltea-ppx`
writes `preventDefault` into its `onClick` at build time; an element with `onDrop` takes drops, so
its `drop`, `dragenter` and `dragover` are cancelled, the last two with no message when the view
gives none; `onSubmit` was already cancelled. Elsewhere `Html.prevent message` asks for it. The
runtime is unchanged (a law in `test/meltea/prevent_laws_test.mlx`, with six mutants: never
cancelling, cancelling every handler, a link to `#` not cancelled, any link cancelled, no
`dragover` added, only `drop` cancelled). The same step then takes 6.5 ms against Svelte's 10.4 in a profile, and in the
scenario 0.92 of Svelte's time. Measured again with it: the geometric mean is 0.72 of React's
and 0.85 of Svelte's (1x; 0.73 and 0.87 at 4x), Meltea faster than Svelte in 9 of 12 steps at
both rates and slower only in `toggle all` at 4x (1.08); the heap is 1.73 MB (1.69 at 4x).

Kanban (1,500 cards in 8 columns, 11 steps) needed four things of Meltea. The dragged card lives in
the model (`Drag_start id`, then `Drop column`), not in `dataTransfer`. Escape comes
through `Sub.key_down`, its columns' `onDrop` cancels what a browser needs cancelled to drop there,
and its dialog goes into `#portal` through `Html.portal ~into:"portal"`: a module of its own in
`meltea.runtime` on `View.host`, made on first use, so a bundle without a portal carries none of it
(a law in `test/meltea/portal_laws_test.mlx`, with four mutants: nodes left behind, the parent
moving the portal's nodes, a new id ignored, nodes shown in place hidden from the parent).
A click inside the dialog stays there through `onClick=Html.stop`: bare, `Html.stop` and
`Html.prevent` send nothing, and wrapped they still send (`Html.prevent (Html.stop message)`).

Spreadsheet (100 by 50 cells of formulas, 11 steps) asked for the typed link the deltas track is
about. Its sheet cancels the arrow keys and the characters it handles, and keys typed into a cell's
editor bubble through the sheet, so cancelling every key would stop typing. Around a function,
`Html.prevent` now cancels exactly the events whose message does something: `Dead`'s reading of
`update` gives the messages whose branch leaves the model as it is and runs no command, and the
handler matches the message it computed against them before it cancels (a law with four mutants:
inert messages cancelled, effective ones not, none found inert, all found inert). The DOM is
identical to React's after every step; `remember` already keeps the evaluation of the sheet to
the changes of `raws`.

Against Svelte (its formulas in plain JavaScript) the steps that change cells were 1.2 to 2.0 times
slower. A profile of `undo x10`: 140 ms of work against Svelte's 45, of which the sheet's
evaluation took 139, nearly all of it building `MelangeError`s. Melange's `float_of_string`
builds its `Failure` with the stack before it reads the string, for every cell that holds a number,
and `float_of_string_opt` raises and catches it for every one that holds a word. With a hand-edited
bundle reading floats without raising, the evaluation took 27.5 ms and the step 45 ms, Svelte's. So
the typed pass now does it: `Unraised` finds `Stdlib.float_of_string_opt` by its exact path in the
typed file and calls `Meltea_runtime.Numbers.float_of_string_opt`, Melange's own reading with `None`
where it raised (a law that both agree on any string built from the pieces the syntax treats
specially, and one that a typed module's call builds no exception where `int_of_string_opt` of a
word builds one; four mutants: no rewrite, `nan`, underscores and minus infinity each dropped).
`int_of_string` raises only when it fails, so it stays.

Measured with it, the DOM identical to both after every step: Meltea's time on spreadsheet is
0.37 to 0.92 of React's per step (the same OCaml formulas, which React's build still reads by
raising), and against Svelte `undo x10` went from 2.03 to 0.90 and `delete 10 cells` from 1.78 to
0.89; slower than Svelte only in `formula bar edit` (1.06) and `edit on double click` (1.07). Over
the three apps the geometric mean is 0.75 of React's time (1x and 4x, slower in no step) and 0.88
of Svelte's (0.89 at 4x, slower in 3 of 36 steps).

The two steps left, `formula bar edit` and `edit on double click`, were a compiler bug the
`fanout` alert pointed at. The alert wrapped the handler it is about in a `let module`, and inside a
list's row that made the row's closure unreadable to the loop compiler, so the sheet's body and its
cells were built by `Html.array` at run time instead of compiled loops; an alert silenced with
`[@alert "-fanout"]` wrapped it all the same. The alert is now a structure item of its own at the
handler's place, as `Dead`'s are, with the handler's alert attributes on it, and the handler is
untouched (`test/ppx/meltea/fanout.t`: such a list compiles to `View.rows` and still gets one
alert; the old placement fails it). All three of the sheet's loops compile now, and on spreadsheet
Meltea is slower than Svelte in no step (0.78 for `formula bar edit`, 1.00 for `edit on double
click`). Over the three apps: 0.74 of React's time (0.73 at 4x) and 0.85 of Svelte's (0.86 at 4x),
slower than Svelte in one step at each rate; measured at a load average of 11 to 17, so the
milliseconds are high, and the ratios stand on runs that alternate the two builds.

Kanban: the DOM is identical to React's and to Svelte's after every step. Meltea's time is 0.80
of React's (1x and 4x, faster in 23 of 24 steps and slower in none) and 0.88 of Svelte's (1x and
4x, slower only in `close card with Escape` at 1x, 6.8 ms against 6.3, with one more style
recalc). The bundle is 20.1 kB gzip (Svelte 26.2, React 53.0); the heap after the scenario is
4.4 MB (React 7.9, Svelte 22.5: deep `$state` puts a proxy on every card, label array and member
array).


## Guards

Every step, before it is pushed: `opam exec -- dune build`, `dune test`, `dune build @runtest-js &&
npx vitest run`, `node bench/ab.mjs --base=origin/main --frameworks=meltea`, `RATCHET_SLOW=1 node
test/ratchet/lower.mjs` and `node test/ratchet/sizes.mjs`. A step that touches `melhole/` also runs
`node bench/ab.mjs` for both frameworks and `node bench/classics/versus.mjs`, since Melact shares it.
