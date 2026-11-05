# The Melact compiler

Melact only looks like React. The surface is reason-react's: components are functions, hooks
keep state, a state change calls the component again. Underneath, the view is compiled the way
[dartea](https://github.com/jongleb/dartea) compiles Elm views: templates with holes, and per
template a generated `refresh` that guards every hole by the values it is computed from.

It relies on the contract React already sets, the Rules of React: rendering is a pure function
of props, state and context. React Compiler relies on the same contract; dartea gets it for free
from Elm.

## Status

Guards are implemented in the shared compiler (`melhole/compiler/free.ml`, `scope.ml`, `element.ml`)
and used by both front ends. The compiler writes out the walk to every hole, and the refresh
writes the holes directly. The runtime is split so that a bundle carries only what the compiled
code calls.

## Guards at the JSX site

The expressions inside a JSX tree only read variables in scope at the JSX site: props, state,
`let`s of the component body, parameters of an enclosing `fun`. For each hole the ppx computes
its free variables, scope-aware, from the AST. Module-qualified names (`String.length`, `Row.make`)
are constants. The ppx then emits, per template site, a refresh function:

```ocaml
View.compiled template 2 (fun scope (click, label, rows_hole) ->
  let count_changed = View.check scope 0 count in          (* one === against the last count *)
  let rows_changed = View.check scope 1 rows in
  View.set_handler click dec;                              (* handlers: swapped, never guarded *)
  (match count_changed with
   | Unchanged -> ()
   | Changed -> View.set_text label (string_of_int count));     (* evaluated only now *)
  match rows_changed with
  | Unchanged -> ()
  | Changed -> View.set_content rows_hole (React.array (Array.map row rows)))
```

`View.check scope k value` compares `value` with the `k`-th remembered dependency and stores
it. On mount nothing is remembered yet, so every hole is evaluated once. A hole whose free
variables are all physically unchanged is neither evaluated nor compared, and a nested JSX tree
inside it is not built at all: `lazy` everywhere, without writing it.

### What is never guarded

- event handlers: a fresh closure each render, swapped on the element without touching the DOM;
- an expression that reads mutable state: `!r`, `r.contents`, `r.current`, `Js.Date`,
  `Js.Math.random`, an assignment, or a variable bound by `for`/`while`;
- an expression with no free variables is constant: evaluated on mount only.

## A runtime made of parts

Nothing at run time interprets a description of the whole view. Every kind of child (text, list,
keyed list, template block, memo, portal) is a value that carries its own code to mount itself and
to patch a mounted child of its kind, and every hole is a typed value written by its own `set_*`.
A bundle therefore contains only the parts its compiled code names.

melhole knows no components: like Elm, it has views that are functions and children that are
values. The child protocol is open (`View.host`, `View.live`, `View.hosted`), and Melact implements
React's components on it in its own library, `melact.runtime`: instances with hook slots, effects in
commit order, context and the scheduler. Meltea never links any of it.

## Compiled walks

The compiler knows the shape of every template, so it writes out how to reach each hole on a
fresh clone, sharing every step:

```ocaml
View.template (Template.html "<p>a<!---->b<!----><b></b></p>") (fun scope p ->
  let n0 = Template.first p in
  let n1 = Template.next n0 in
  ...
  (View.text_hole { parent = p; before = Template.next_or_end n0 }, ...))
```

It also decides at compile time whether the root is an SVG element. The runtime keeps no paths
and no tag tables. A law checks the walk: interpreted over the parsed HTML, every step starts
from a node reached before it and lands on the node the hole names.

## Direct writes

The walk makes the holes once per clone: a text node, an attribute, a property, a handler, a
place for child content. The refresh gets them as a typed tuple and writes each one directly,
`set_text label (string_of_int count)`, with no index, no table of bindings and no "not bound
yet" case. Mounting is the same refresh on fresh holes, where every check reports a change, so
each hole expression appears once in the generated code. A later render of the same JSX site
finds the mounted holes through its template: the mounted clone lends them to the template, and
the refresh that belongs to that template takes them back, typed, without `Obj` or a type witness.

## Compiled lists

`Html.list (List.map row items)` in a content hole compiles to a keyed loop, `View.each`, instead
of a list of row descriptions. The compiler finds what a row reads besides its item: the free
variables of `row`, looking through local `let` definitions. If none of them changed and an item is
physically the same as before, the loop keeps the row as it is and never calls `row`.

When an outer variable does change, the loop does not re-render every row. As in Vue Vapor's
selectors, the compiler splits the row into its item and the smallest pieces without JSX that read
outer variables (its leaves), for example

```ocaml
match selected with Some id when id = item.id -> "danger" | _ -> ""
```

and emits a projection that evaluates only those leaves for an item. A row is re-rendered only when
its projection changed: selecting a row of 1,000 re-renders two. Leaves that build fresh values
(closures, records) never compare equal, so such rows simply re-render; that is slower, never wrong.
A law runs random messages against a view whose rows read two outer values and compares the page
with a fresh mount.

## The Rules of Hooks, checked by the type checker

Every hook in `React` carries an alert, `[@@alert hook]`. `melact-ppx` turns the alert off for the
whole file and back on in the branches, loops and callbacks of a component body. A hook called
there is then reported by the OCaml type checker itself, which resolves it through any alias
(`module R = React`, `open React`). It is a warning, not an error, so reason-react code that bends
the rule still compiles.

## Fields an update changes

`meltea-ppx` reads `update` the way Svelte 4 reads assignments. For every message it finds which
model fields the branch can change: `{ model with draft }` changes `draft`, `model` changes
nothing, anything it does not recognise changes everything. It reads `view` the same way: the
fields a record pattern names, or the fields read through `model.field`. Both become bit masks over
field names, and `Program` keeps the fields changed since the last draw. If none of them is one the
view reads, the view is not called at all. No signals and nothing in the user's code: the masks are
generated next to `update` and `view` and passed to `Program` by the compiler. Inside the view,
`===` stays the exact check for what to write.

The masks travel between modules without types. Each companion is evidence: the masks and the
function they were found in. At `Program.element ~update:Todomvc.update` the compiler looks the
companion up with `open! Todomvc` over a fallback that says "not analysed", so a module the
compiler never saw, or an `.mli` that hides the companion, still compiles. `Program.track` then
checks once that the companion describes the function in use (`analysed == Todomvc.update`); a
redefined `update` or a different function gets no masks. A wrapper such as
`fun message model -> let next, command = Todomvc.update message model in (next, …)` changes what
`Todomvc.update` changes, and is recognised as such. `update` may start with helper `let`s before
its `match`.

## Components without hooks

By the Rules of React every hook is named `use…`, so `melact-ppx` sees whether a component's body
can call one. A component that calls none is a function of its props: it compiles to
`View.pure`, a child that keeps the component's identity and props and nothing else. The same
component with the same props is left as it is, new props re-render it, and another component in
its place mounts afresh, as React does. Only components that call hooks get an instance with hook
slots, effects and a place in the scheduler. A dual test checks the remount against React 18:
replacing one hookless component by another with the same output resets the state below it.

## Controlled inputs

`value` and `checked` are properties the user changes too. A guard compares a value with the one
written last, so when typing changes the DOM but not the state (an update that rejects or
filters the text, or a field cleared to the `""` it already held), nothing would write it back.
These two props become controlled holes, as in React: after an `input` or `change` event on the
element, and after the redraw the event causes, the hole puts its last written value back if the
DOM differs. The guard stays; the check after input costs one property read. One law, run against
reason-react with React 18 and against Melact, types and clicks into a controlled field and
checkbox whose handlers keep or reject the input, and compares what the page shows.

## Laws

Accepted only with these holding, by property-based tests:

- **Equivalence:** a guarded refresh renders the same DOM and runs the same effects as an
  unguarded one, for any component and any sequence of state and prop changes.
- **Guard soundness:** a hole is evaluated whenever one of its free variables changed.
- **Guard economy:** a hole whose free variables are all unchanged is not evaluated.
- **Volatility:** a hole that reads mutable state is evaluated on every render.
