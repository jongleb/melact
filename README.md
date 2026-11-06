<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg">
  <img src="assets/logo.svg" alt="Melact: frames turning into a funnel around one live hole" width="120">
</picture>

# melact

**reason-react for Melange, without React and without a virtual DOM.**

JSX compiles to DOM templates with holes. A re-render writes only the holes whose values changed.

![status](https://img.shields.io/badge/status-milestone%204%20of%207-8250df)
![Melange](https://img.shields.io/badge/Melange-%E2%89%A5%205.1-ec6813?logo=ocaml&logoColor=white)
![OCaml](https://img.shields.io/badge/OCaml-%E2%89%A5%205.4-ec6813?logo=ocaml&logoColor=white)
![syntax](https://img.shields.io/badge/JSX-mlx%20%C2%B7%20Reason%20%C2%B7%20OCaml-1f6feb)
![runtime deps](https://img.shields.io/badge/npm%20runtime%20deps-0-1a7f37)

[The idea](#the-idea) · [How it works](#how-it-works) · [Status](#status) ·
[Try it](#try-it) · [Roadmap](#roadmap) · [Not goals](#not-goals)

</div>

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/overview-dark.svg">
  <img src="assets/overview.svg" alt="Melact in one picture. 1: you keep a reason-react component unchanged; the whole migration is two dune lines. 2: Melact compiles it once, at build time, into a template with two holes, the click handler and the text n, the only places that can change, and a generated render: if n !== last then text.data = n, one compare per value and at most one write per change. 3: a click runs your set as before, only this component runs, n goes from 0 to 1 so one === fails, and text.data = 1 is the only DOM write. Gone: React, react-dom, the virtual DOM, a tree per render, the tree diff, fiber. Stays: your components, hooks, mlx, Reason and OCaml, ReactDOM, React.Event. Starting fresh? Write Meltea" width="100%">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/speed-dark.svg">
  <img src="assets/speed.svg" alt="Benchmark: within ×1.2 of hand-written JavaScript. js-framework-benchmark's keyed operations in headless Chrome, slowdown against vanilla JS, lower is better: vanilla 1.00, Meltea 1.15, Melact 1.17, React 18 1.70. JS bundle of the benchmark app, gzip: vanilla 1.4 kB, Meltea 9.0, Melact 9.9, React 18 45.6. Heap with 1,000 rows: vanilla 0.77 MB, Meltea 1.22, Melact 1.64, React 18 3.17. Swapping two rows of 1,000: Meltea 1.12, Melact 1.17, React 18 5.86" width="100%">
</picture>

> [!NOTE]
> **Milestones 1–3 of 7 are done:** the `View` layer, components with hooks, and `melact-ppx`.
> A reason-react component in mlx, Reason or OCaml compiles and runs, and one test suite passes
> both against reason-react with React 18 and against Melact. Milestone 4, the rest of the
> reason-react surface, is done too: the full `React.Event`, `React.createElement` with
> `makeProps`, `ReasonReactRouter`, and a community TodoMVC that runs on Melact with only its
> `dune` file changed.

## The idea

> Melact has a sibling, **Meltea**: the Elm architecture in OCaml, pure functions everywhere,
> views in mlx. Both share one Svelte-like compiler and a runtime that tends to zero. See
> [Meltea](#meltea) below and [`docs/vision.md`](docs/vision.md).

Take a reason-react + Melange app, change two lines in its `dune` files:

```diff
- (libraries reason-react)
+ (libraries melact)
- (preprocess (pps reason-react-ppx))
+ (preprocess (pps melact-ppx))
```

and get a build with no React in the bundle and no virtual DOM. Your components stay as they are:

```ocaml
(* counter.mlx *)
let[@react.component] make ~initial () =
  let count, setCount = React.useState (fun () -> initial) in
  let dec _ = setCount (fun n -> n - 1) in
  let tone = if count < 0 then "warm" else "calm" in
  <div className="counter">
    <button onClick=dec>(React.string "-")</button>
    <output className=tone>(React.int count)</output>
  </div>
```

melact keeps reason-react's surface (`React.useState`, `useEffect`, `useContext`, `ReactDOM.Client`,
`React.Event`, `ReasonReactRouter` …) and replaces what is underneath it.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/surface-dark.svg">
  <img src="assets/surface.svg" alt="What melact-ppx and the Melact library make of unchanged reason-react code: a JSX component is makeProps building the element, with make the identity; React.createElement with makeProps is the same element with a key; React.Event accessors read the native event, delegated to document; each hook call gets a typed slot key; a component without hooks is a pure view with no instance; ReactDOM.Client clones templates into the element; renderToString and hydrateRoot are Served.render and Served.hydrate; ReasonReactRouter.useUrl reads the location on popstate" width="100%">
</picture>

*Each line of reason-react code on the left compiles, unchanged, to what is on the right.*

## Why melact

<table>
<tr>
<td width="50%" valign="top">

**No virtual DOM.** A render does not build a tree of elements to diff. It builds one array: the
values of the holes in a template. Everything static is parsed once, at module load, and cloned.

</td>
<td width="50%" valign="top">

**The Elm model, made exact.** "Did this hole change" is `===`. An unchanged reference is an
unchanged value, so a physically equal child list or `lazy` argument skips its whole subtree.

</td>
</tr>
<tr>
<td valign="top">

**Updates start where state changed.** A `setState` re-renders its own component, not the
root. Children with physically unchanged props are skipped without `memo`.

</td>
<td valign="top">

**Few DOM moves for lists.** Keyed lists keep their common prefix and suffix, and the longest
increasing run of old positions. Swapping two of 1,000 rows is 2 `insertBefore` calls.

</td>
</tr>
<tr>
<td valign="top">

**One listener per event type.** Bubbling events are delegated to `document`. A handler is a
property on its element, so a new closure each render costs one property write.

</td>
<td valign="top">

**Still reason-react.** Same JSX in mlx, Reason or OCaml `[@JSX]`, and the same hooks with the
same signatures. Pure-OCaml reason-react code is the compatibility target.

</td>
</tr>
</table>

## How it works

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/vdom-dark.svg">
  <img src="assets/vdom.svg" alt="One click in the counter, from 1 to 2. React builds a new tree of 5 elements and 5 props objects, walks it against the previous tree and writes one text. Melact keeps the markup as a template parsed once, builds one array of 6 hole values, compares each with === and writes the same one text" width="100%">
</picture>

*No virtual DOM: the DOM writes are the same, what disappears is the copy of the tree that React rebuilds and walks on every render.*

### JSX becomes a template and a hole array

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/pipeline-dark.svg">
  <img src="assets/pipeline.svg" alt="mlx JSX is compiled into a template hoisted to module level and a walk to its three holes: b is the first child of the div, o the next sibling of b, and the text goes at the end of o; the template is cloned once per mount; every render runs the compiled refresh, which checks count and tone and writes only the holes that read a changed one" width="100%">
</picture>

- **Template.** The largest static subtree of every JSX site (lowercase tags, literal attributes,
  literal text) becomes one HTML string, parsed once into a `<template>` and cloned with
  `cloneNode(true)` per mount.
- **Holes.** Each dynamic attribute, handler, text or child is a hole: an element, or a parent and
  the node to insert before. The compiler emits the walk to them, `firstChild` and `nextSibling`
  only, as Svelte does; it runs on the fresh clone before anything is inserted, so nothing shifts.
- **Refresh.** For every template the compiler also emits a refresh function, as Svelte and
  dartea do. It checks each local the view reads with one `===`, and evaluates and writes only
  the holes that read a changed one. Holes that read nothing that changed are not even computed,
  so a nested tree or a `List.map` over rows behind an unchanged local costs nothing.

### A render is one `===` per local

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/patch-dark.svg">
  <img src="assets/patch.svg" alt="The compiled refresh of counter-react on a click from 41 to 42: count changed, so the text and disabled holes run and the text node gets 42; tone and initial are the same, so the class hole is not even evaluated; handlers are swapped on the element without DOM calls" width="100%">
</picture>

Nothing is built to be compared afterwards. The refresh the compiler generated checks each local
the view reads, then runs only the holes that read a changed one, each writing its own node:

| hole | written with |
|---|---|
| text | `node.data = s` |
| attribute | `setAttribute` / `removeAttribute` (`None` removes) |
| property | `el[name] = v` (`value`, `checked`, `innerHTML`) |
| style | the old properties cleared, the new ones set |
| handler | guarded by the locals it reads, like any hole; Melact replaces the closure on the element, Meltea writes only the data the message needs and shares one handler per site |
| ref | the new callback is called with the element |
| child | patched recursively: a template, a list, a component |

### Keyed lists move as little as possible

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/reconcile-dark.svg">
  <img src="assets/reconcile.svg" alt="Keyed reconcile: the common prefix a and suffix f stay, c and d form the longest increasing run of old positions and stay, b and e are moved with one insertBefore each. Measured on 1,000 rows: swap 2 moves, reverse 999 moves, remove one keeps 999 rows" width="100%">
</picture>

`Reconcile.plan` takes the old and new keys and returns a step per new entry: `Keep`, `Move` or
`Create`, plus the old entries to drop. It tries the cheap cases first: common ends (a swapped
first and last row is two moves), an empty side, then a small hash table from old keys to
positions and the longest increasing run. When the keys keep their order the loop skips the plan
and patches rows in place. The plan touches no DOM, so it is tested on its own. `View` walks the
new entries right to left, inserting before the first node of the entry after. Duplicate keys
never reuse one old entry twice.

### Rows re-render only when what they read changed

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/selectors-dark.svg">
  <img src="assets/selectors.svg" alt="Compiled selectors, after Vue Vapor: a row of Html.list (List.map …) reads its item and the outer value selected through one leaf without JSX; the compiler emits a projection that evaluates only that leaf for each row. When selected goes from Some 2 to Some 5 and the six items are the same objects, only rows 2 and 5 have a changed projection, so only they render, in place; the other four are kept without calling the row function" width="100%">
</picture>

`React.array (Array.map row items)` and Meltea's `Html.list (List.map row items)` compile to a
keyed loop. As in Vue Vapor's selectors, the compiler splits a row into its item and its leaves,
the smallest pieces without JSX that read outer variables, and emits a projection that evaluates
only those. A row whose item is the same object and whose projection did not change is kept
without calling the row function: selecting one row of 1,000 renders two.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/row-dark.svg">
  <img src="assets/row.svg" alt="What one row of a compiled list holds. Before: a child description with build and patch closures, a with_key wrapper, a refresh closure, a mounted child with three closures, a compiled state with a lend closure, a scope with its deps, a holes array with five hole records, two handler closures and a projection array. Now: one Mounted_row record with the root, the scope and the holes, the scope\'s deps also holding the last written values, the holes as bare nodes, the handler data as a property of the element, and the projection array; the template, one refresh per list, the key function and one handler per site are shared. Creating 1,000 rows allocates about 430 kB instead of 939, and 1,000 rows take 1.22 MB instead of 1.68" width="100%">
</picture>

A row that is one element with a `key` compiles further, to `View.rows`: one record per row, holes
that are the bare nodes, the last written values kept next to the guarded locals, and in Meltea
one handler per site that reads the row's data from the element it was clicked on.

### Events are delegated

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/events-dark.svg">
  <img src="assets/events.svg" alt="One listener per event type on the document; on a click melact walks from the target up through parent nodes and calls the handler stored on each element; replacing a handler is one property write" width="100%">
</picture>

The 22 delegated types are the bubbling set Solid uses: `click`, `input`, `keydown`, `focusin`,
`pointer*`, `mouse*`, `touch*` and the rest. Any other event gets one listener on its element that
reads the same property, so replacing its handler is free too. That listener is removed on unmount.

### Inputs show the state

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/controlled-dark.svg">
  <img src="assets/controlled.svg" alt="Controlled inputs: the user types milk and presses Enter in the same tick; the model's field goes from empty to milk and back to empty, so the redraw sees an unchanged value and writes nothing. A guard alone leaves milk in the field. In Meltea and Melact value and checked are controlled holes: after an input or change event and the redraw it causes, the hole writes its last value back if the DOM differs, as React does" width="100%">
</picture>

A guard compares a value with the one written last, but the user changes `value` and `checked`
too. So these two props are controlled holes: after an `input` or `change` event, and the redraw
it causes, the hole writes its last value back if the DOM differs. A handler that filters or
rejects input keeps the field in step with the state, as in React; one law types into such a
field and checkbox under React 18 and under Melact and compares the page.

### Server rendering and hydration

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hydration-dark.svg">
  <img src="assets/hydration.svg" alt="Server rendering and hydration in React's format: on the server Program.render, renderToString or server-reason-react write plain HTML with no markers, and a comment only between two adjacent texts; in the browser, code the compiler generated for each template walks the server's nodes in document order, after an off-page clone has let the template's own refresh compute the values: the root with the same tag is taken over, texts and lists take exactly their nodes, and the buttons get their handlers; no element is added to the page, and HTML that does not match the view is cleared and mounted from scratch. Before the code arrives, the capture script in the page's head records clicks, typing and key presses with each target's value, and hydration delivers them in order" width="100%">
</picture>

`ReactDOMServer.renderToString` (Meltea: `Program.render`) writes HTML in the format of React's own
`renderToString`, with no markers, so a Melact app can also render on a native OCaml server with
[server-reason-react](https://github.com/ml-in-barcelona/server-reason-react).
`ReactDOM.Client.hydrateRoot` (`~start:Program.hydrate`) takes that HTML over in document order
with code the compiler generates for each template under its `-hydratable` flag: it keeps the
server's elements and sets handlers. HTML that does not match the view is replaced by a normal
mount. `Melhole_server.capture`, a script for the page's head, records what the user does before
the code arrives, with each field's value at that moment, and hydration delivers it in order.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/served-dark.svg">
  <img src="assets/served.svg" alt="One Meltea module, page.mlx, built twice. meltea-ppx for the browser compiles the view into a template parsed once and cloned, a walk to the output and a refresh that writes the text only when count changed. meltea-ppx -server compiles the same view into code that writes strings with no DOM, natively or in Node: the static markup joined into a few strings at compile time and one call per dynamic part, the class and the count. The server writes HTML in React's format, the same bytes natively and under Melange, and the browser build hydrates it" width="100%">
</picture>

A server does not need a DOM either. Under `meltea-ppx -server` the same view compiles to code
that writes its HTML through `melhole.server`, plain OCaml that runs natively and in Node:
static markup joined into a few strings at compile time and one call per dynamic part.
`meltea.server` has Meltea's `Html`, `Cmd`, `Sub` and `Program`, so one module with the model,
`update` and `view` builds for both sides; [`examples/served`](examples/served) is a native
server and the client that hydrates its page.

### Components re-render where state changed

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/updates-dark.svg">
  <img src="assets/updates.svg" alt="A state update in TodoList re-renders TodoList only; App and Header are not visited; Rows whose props are physically equal are skipped" width="100%">
</picture>

Each `[@react.component]` gets an identity at module level. Its props are compared one by one
with `===`. A component that calls no hook compiles to a pure view with no instance, kept while
its props are the same. A setter marks its instance dirty, and one microtask
renders the dirty instances parents first. Layout effects run right after their instance's
patch. Passive effects run after the whole flush, and cleanups go children before parents. A
component that renders nothing keeps its place with an empty text node.

### Hooks are typed by their call site

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hooks-dark.svg">
  <img src="assets/hooks.svg" alt="melact-ppx gives every hook call site its own Type.Id key, hoisted to module level; the instance stores each slot with the key that made it; reading a slot checks provably_equal, so values come back typed, and a hook called out of order raises an error instead of returning a wrong value" width="100%">
</picture>

Hooks keep state in slots read in call order, as in React. Instead of casting what a slot holds,
`melact-ppx` gives every `React.useState`, `useEffect`, `useMemo`… call site its own key,
a `Type.Id` created once at module level, and passes it as a hidden first argument:

```ocaml
(* you write *)
let count, setCount = React.useState (fun () -> 0)

(* melact-ppx emits *)
let __melhole_hook_2 = Melact_runtime.Hook.key ()
let count, setCount = (React.useState __melhole_hook_2) (fun () -> 0)
```

A slot stores its value with the key that made it, so reading it back is a typed
`Type.Id.provably_equal`, with no `Obj.magic`. A hook inside an `if`, a `match`, a loop or a
callback raises the `hook` alert at build time; at run time a hook called out of order raises
*"hooks were called in a different order"* instead of handing back the wrong value. Using one
key at two types is a compile error. Hooks inside custom hooks get keys the same way.

### Mutate in place, and nothing updates

Change detection is physical equality, exactly as in Elm. Code that mutates an array or a
record in place and passes the same reference back will not re-render that part. Idiomatic OCaml
builds new values, so this rarely matters, but it is a rule rather than an optimisation.

## Meltea

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/meltea-dark.svg">
    <img src="assets/meltea.svg" alt="Meltea: a tea glass with a hole in orbit around it" width="120">
  </picture>
</p>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/family-dark.svg">
  <img src="assets/family.svg" alt="Two front ends, one compiler, one runtime: Meltea views in mlx go through meltea-ppx, Melact components in reason-react style go through melact-ppx; both reach the shared compiler, which makes templates, walks to every hole and compiles lists into keyed loops with selectors, and the shared runtime melhole, which knows no components; Melact adds its own runtime library, melact.runtime, with components, hooks and the scheduler" width="100%">
</picture>

Meltea is the Elm architecture in OCaml: a model, messages, a pure `update` and a pure `view`
in mlx. No hooks and no components with state: an event handler is a message.

```ocaml
type message = Increment | Decrement | Reset

let update message count =
  match message with Increment -> count + 1 | Decrement -> count - 1 | Reset -> 0

let view count =
  <div className="counter">
    <button onClick=Decrement>(Html.text "-")</button>
    <output>(Html.int count)</output>
    <button onClick=Increment>(Html.text "+")</button>
    <button onClick=Reset disabled=(count = 0)>(Html.text "reset")</button>
  </div>

let () = Option.iter (fun root -> ignore (Program.sandbox ~init:0 ~update ~view root)) root
```

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/compiled-dark.svg">
  <img src="assets/compiled.svg" alt="The counter in Meltea: you write the view in mlx; Meltea compiles it into a template tree of div, two buttons and an output whose text is the only hole; when + is clicked the update makes count 42, the compiled code compares count with its last value and writes 42 into that one text node; the grey static nodes get no DOM writes; there is no virtual DOM" width="100%">
</picture>

`meltea-ppx` compiles the view with the same template compiler as `melact-ppx`. `onClick=Increment`
sends a message, `onInput` and `onKeyDown` take a function of the value or key, `onCheck` of the
checked state. `Program.sandbox` and `Program.element` run it, with `Cmd` and `Sub` as plain
values; `Html.map` and `Html.memo` work as in Elm. Dependencies: `(libraries meltea)` and
`(pps melange.ppx meltea-ppx)`. Examples: [`examples/counter`](examples/counter/main.mlx) and
[`examples/todomvc`](examples/todomvc/todomvc.mlx), the full TodoMVC with routing, editing and
`localStorage`.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/fields-dark.svg">
  <img src="assets/fields.svg" alt="Fields an update changes, in Meltea's TodoMVC: meltea-ppx reads update and finds what each message can change: Type changes field, Route changes filter, Add changes todos, field and next, Ignore changes nothing, and Edit, which it does not recognise, changes all fields. It reads view the same way: todos, field, editing and filter, never next. After Ignore nothing the view reads changed, so the view is not called; after Type the view runs and one === per local picks the holes to write" width="100%">
</picture>

`meltea-ppx` also reads `update` and `view` for the model fields each message can change and the
view reads. A message that changes nothing the view reads does not call the view at all.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/fanout-dark.svg">
  <img src="assets/fanout.svg" alt="Fanout in Meltea's TodoMVC: meltea-ppx follows a frequent event to the lists it reaches. The edit field's onInput sends Retype, whose branch of update writes editing, and the list in view reads todos, filter and editing, so every keystroke makes the list check all its rows; the compiler raises the alert fanout at the handler. The new-todo field's onInput sends Type, which writes field, which no list reads, so typing writes one hole and there is no alert. A key handler's literal branch such as Enter sends Add once and does not count" width="100%">
</picture>

The same reading follows every frequent event (typing, keys, pointer moves, scroll) through the
message it sends and the fields that message writes to the lists that read them. Where typing
would make a list check all its rows on every keystroke, the compiler says so at the handler with
an alert, `fanout`, and the user writes nothing to get it.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/remember-dark.svg">
  <img src="assets/remember.svg" alt="Remembered values in a Meltea view: Type m changes only the draft field. Without remembering, let shown = List.filter over model.items builds a new list on every call, so the list hole sees a different value and checks all 1,000 rows. meltea-ppx compiles the let to View.remember keyed by model.filter and model.items; both are the same objects, so the old list comes back, the hole is skipped, and only the draft hole is written" width="100%">
</picture>

A derived `let` at the top of a view is remembered by the fields it reads, so typing in a field no
longer rebuilds a filtered list and makes its loop check every row.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hot-dark.svg">
  <img src="assets/hot.svg" alt="Hot reload in Meltea: a program runs on the root with its model and the shape of its module's types. After an edit, Vite runs main.mlx again, and Program.element with ~start:Program.hot finds the running program; when the new code's shape is the same, the model carries over and the new view and update show the old state; when the types changed, the program starts from init" width="100%">
</picture>

`~start:Program.hot` with Vite's HMR shows an edit as the new view of the old model, as elm-watch
does, and starts from `init` when the module's types changed.

### Transitions

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/transition-dark.svg">
  <img src="assets/transition.svg" alt="Transitions, as Vue's Transition and TransitionGroup, with name fade. Enter: in the patch the new row b gets fade-enter-from and fade-enter-active, two frames later fade-enter-to replaces fade-enter-from while CSS animates, and when the duration is up no classes are left. Leave: the removed row b is put back where it was with fade-leave-from and fade-leave-active, two frames later fade-leave-to, and when the duration is up it leaves the DOM. Move, in a group: row c went first, so after the patch the DOM is c a b but a transform shows every moved row where it was; two frames later the rows get fade-move and the transforms are cleared, so they slide to their new places; at the end no classes are left" width="100%">
</picture>

`Html.transition ~name` and `Html.transition_group ~name` animate what enters and leaves, as Vue's
`<Transition>` and `<TransitionGroup>`: CSS classes named after `name`, the leaving element kept
in place until its transition ends, and in a group the rows that move slid from where they were
(FLIP). A list inside a group is still the compiled keyed loop with selectors. The code lives in
melhole's `Transition` module, so an app that does not animate does not carry it.

```ocaml
let view model =
  <ul className="todo-list">
    (Html.transition_group ~name:"fade" (Html.list (List.map row (visible model))))
  </ul>
```

```css
.fade-enter-from, .fade-leave-to { opacity: 0; }
.fade-enter-active, .fade-leave-active, .fade-move { transition: all 200ms; }
```

## Status

[`compat/run.sh`](compat/run.sh) clones reason-react, melange-opam-template and reason-seoul's TodoMVC, changes two lines
in their `dune` files and builds them against Melact. Then it renders reason-react's demo with React and with Melact and
compares the DOM after every click (37 steps, all identical), and walks the TodoMVC randomly (five walks, 605 steps of clicks, typing, submits and
route changes) comparing the DOM after every step. The TodoMVC was written for reason-react 0.9, so both copies first get
the same upgrade to reason-react 0.17 (`ReactEvent.` becomes `React.Event.`, and `Index.re` uses `ReactDOM.Client`). One
demo component binds React's own `useReducer` from npm (`external … [@@mel.module "react"]`); melact-ppx
rewrites such bindings to Melact's hooks (`useState`, `useReducer`, `useEffect` with or without deps, `useMemo`,
`useCallback`, `useRef`, `useContext`, `createPortal`, …), so it runs as it is.

| | |
|---|---|
| **Works** | `View`, `Template`, `Reconcile`, delegated events; components, context and every reason-react hook with a key (`useState`, `useReducer`, `useEffect*`, `useLayoutEffect*`, `useMemo*`, `useCallback*`, `useRef`, `useImperativeHandle*`, `useId`, `useInsertionEffect0`–`7`, `useSyncExternalStore` and `…WithServer`, `useDeferredValue`, `useTransition` and `useTransitionAsync`); `React.memo`, `React.act`, `ReactDOM.Client`, `ReactDOM.Style`, `ReactDOM.Ref`, every `React.Event` family over native events (handlers see the `currentTarget` they were set on, as in React), `React.createElement`, `React.jsx`, `jsxKeyed` and friends with `makeProps`, code typed against `React.component('props)` (wrappers, `React.memo`, `React.component`, hand-written modules with a `[@mel.obj] makeProps` and `props##field`), `ReasonReactRouter`, `ReactDOMTestUtils` (`Simulate` sends the native event Melact listens to), `ReasonReactErrorBoundary` (render, update and effect errors handled pass by pass as React 18 does); DOM elements built at run time with `ReactDOM.domProps`, `ReactDOM.createElement`, `createDOMElementVariadic`, `jsx`, `stringToComponent` and `React.createElementVariadic`; bindings written to npm's `react` (`[@@mel.module "react"]`) rewritten to Melact's hooks, dependencies as arrays or tuples, also when the bindings live in another file, and bindings to npm's `createElement`, `jsx`, `jsxs` and `Fragment` that return a `React.element` build Melact elements; `melact-ppx` for Reason, OCaml `[@JSX]` and mlx |
| **Size** | whole apps, runtime and the Melange stdlib they use included: the counter is 3.0 kB gzip with Meltea and 5.6 kB with Melact, TodoMVC in Meltea is 14.7 kB, most of it jsonkit's `Printf` for error messages; React 18.3 and react-dom alone are 45 kB |
| **Speed** | [`bench/`](bench/README.md) reproduces js-framework-benchmark's keyed operations in headless Chrome: geometric mean of the slowdown against hand-written vanilla JS is 1.15 for Meltea, 1.17 for Melact and 1.70 for React 18 (the ratios move by about 0.1 between runs); a list re-renders only the rows whose item changed, and swapping two rows of 1,000 moves two rows (React moves 998) |
| **Tests** | 160 vitest + jsdom tests and 25 native QCheck laws: the View layer, transitions under fake timers, the keyed loop and its projections, pure components, hooks against `View` directly, and one suite in mlx built twice, against reason-react with React 18 and against melact, with identical assertions. `melact-ppx` has expect tests for every JSX shape in [`test/ppx/jsx.t`](test/ppx/jsx.t) |
| **Examples** | [`examples/counter-react`](examples/counter-react/counter.mlx), Melact in reason-react style; [`examples/counter`](examples/counter/main.mlx) and [`examples/todomvc`](examples/todomvc/todomvc.mlx), Meltea |
| **Server** | `ReactDOMServer.renderToString` and `ReactDOM.Client.hydrateRoot`; Meltea has `Program.render` and `~start:Program.hydrate`. The HTML is in React's format, so React's own and server-reason-react's hydrate too; hydration code is compiled under `-hydratable`. `meltea-ppx -server` compiles a view to code that writes its HTML with no DOM, natively or in Node ([`examples/served`](examples/served)); a Melact app renders natively with server-reason-react. `Melhole_server.capture`, a script for the page's head, keeps clicks and typing made before the code arrives and hydration delivers them |
| **Not yet** | `React.Experimental` (React 19's `use`, `useOptimistic`, `useActionState`), `ReactDOMTestUtils.isElementOfType`, reading a `domProps` back field by field, Suspense on the server |
| **Limits** | a `make` written by hand with labels and no `[@react.component]` is not a component in JSX (it is not in reason-react either): mark it `[@react.component]`; a hand-written `make` that calls hooks runs them in its parent, so call it unconditionally; a component or custom hook that is polymorphic in its state type gets a weak type for its hook key; annotate it, or keep the state type concrete |

A whole tree compiles to one template. This mlx counter is one `<template>` with six holes,
the same as the hand-written one:

```ocaml
let[@react.component] make ~initial () =
  let count, setCount = React.useState (fun () -> initial) in
  let tone = if count < 0 then "negative" else "" in
  <div className="counter">
    <button onClick=(fun _ -> setCount (fun n -> n - 1))>(React.string "-")</button>
    <output className=tone>(React.int count)</output>
    <button onClick=(fun _ -> setCount (fun n -> n + 1))>(React.string "+")</button>
    <button onClick=(fun _ -> setCount (fun _ -> initial)) disabled=(count = initial)>
      (React.string "reset")
    </button>
  </div>
```

## Try it

You need OCaml ≥ 5.4, Melange ≥ 5.1, dune ≥ 3.16 and Node for the tests.

```console
$ dune build                          # libraries and examples
$ dune build @runtest-js && npx vitest run
 ✓ test/view/view_test.mjs (17 tests)
 ✓ test/view/reconcile_test.mjs (9 tests)
 ✓ test/react/hooks_test.mjs (15 tests)
 ✓ test/dual/react/dual_test.mjs (11 tests)
 ✓ test/dual/melact/dual_test.mjs (11 tests)
$ dune test test/ppx                  # melact-ppx expect tests
$ npx vite                            # then open http://localhost:5173/examples/counter/
```

`vite.config.js` resolves the bare imports Melange emits (`melange.js/…`) inside each
`_build/…/output` directory, for vitest and for the examples alike.

## Roadmap

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/roadmap-dark.svg">
  <img src="assets/roadmap.svg" alt="Roadmap: View, hooks, melact-ppx, compatibility, speed and server rendering with hydration done; publishing in progress: CI runs every law, the opam release is next" width="100%">
</picture>

| # | milestone | done when |
|---|---|---|
| 1 | **View** ✓ | patch pairs, reconcile operations, events and `lazy` pass in jsdom; the counter runs |
| 2 | **Hooks** ✓ | one test suite passes twice: against reason-react with real React, and against melact |
| 3 | **melact-ppx** ✓ | the counter in reason-react style compiles to one template with the same holes as by hand |
| 4 | **Compat** | reason-react's examples and TodoMVC build unmodified and behave identically |
| 5 | **Speed** ✓ | keyed loops, selectors and pure components: about 1.2× vanilla JS on the keyed benchmark, React 18 about 1.7× |
| 6 | **SSR** ✓ | `ReactDOMServer.renderToString` / `Program.render`, and hydration that takes the server's nodes over |
| 7 | **Publish** (now) | CI runs every law on each push ✓; next, the opam packages `melhole`, `melact`, `melact-ppx`, `meltea`, `meltea-ppx` |

The full plan is in [`SPEC.md`](SPEC.md).

## Not goals

- **npm React components.** `react-query` and other packages from npm will not work. Only
  OCaml reason-react code is the target.
- **Suspense, concurrent rendering, `useTransition` semantics.** `useTransition` and
  `startTransition` run synchronously.
- **Server components.**
- **Signals.** There is no reactive graph. A component function runs again, and its holes are
  compared.

## Layout

```
melhole/runtime     melhole           shared runtime: templates, guards, keyed moves, events
melhole/server      melhole.server    HTML without a DOM, natively or under Melange
react/runtime       melact.runtime    React's components: instances, hook slots, context, scheduler
melhole/compiler    melhole.compiler  shared compiler: templates, scopes, guards, DOM props
ppx/melact         melact-ppx       JSX, [@react.component], hook keys
ppx/meltea         meltea-ppx       mlx views with messages
react/             melact           React (with React.Event), ReactDOM, ReasonReactRouter
meltea/            meltea           the Elm architecture: Program, Cmd, Sub, Html
meltea/server      meltea.server    the same modules on a server: views write HTML
test/                               laws: QCheck, fast-check in jsdom, React vs Melact
examples/                           counter (Meltea), counter-react (Melact)
compat/                             real reason-react apps built against Melact
assets/                             the figures above: python3 assets/make.py
```
