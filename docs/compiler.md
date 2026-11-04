# The Melact compiler

Melact only looks like React. The surface is reason-react's: components are functions, hooks
keep state, a state change calls the component again. Underneath, the view is compiled the way
[dartea](https://github.com/jongleb/dartea) compiles Elm views: templates with holes, and per
template a generated `refresh` that guards every hole by the values it is computed from.

It relies on the contract React already sets, the Rules of React: rendering is a pure function
of props, state and context. React Compiler relies on the same contract; dartea gets it for free
from Elm.

## Today

`melact-ppx` turns a JSX tree into one `Template.t` (static HTML, parsed once) and builds, on
every render, an array with the value of every hole. `View` compares each value with `===` and
writes what changed. Every hole expression is evaluated on every render, including nested JSX
and `List.map` over rows.

## Guards at the JSX site

The expressions inside a JSX tree only read variables in scope at the JSX site: props, state,
`let`s of the component body, parameters of an enclosing `fun`. For each hole the ppx computes
its free variables, scope-aware, from the AST. Module-qualified names (`String.length`, `Row.make`)
are constants. The ppx then emits, per template site, a refresh function:

```ocaml
fun block ->
  View.put block 0 (HHandler dec);                         (* handlers: swapped, never guarded *)
  if View.changed block 0 count then                       (* one === against the last count *)
    View.put block 1 (HText (string_of_int count));        (* evaluated only now *)
  if View.changed block 1 rows then
    View.put block 2 (HChild (React.array (Array.map row rows)))
```

`View.changed block k value` compares `value` with the `k`-th remembered dependency and stores
it. On mount nothing is remembered yet, so every hole is evaluated once. A hole whose free
variables are all physically unchanged is neither evaluated nor compared, and a nested JSX tree
inside it is not built at all: `lazy` everywhere, without writing it.

### What is never guarded

- event handlers: a fresh closure each render, swapped on the element without touching the DOM;
- an expression that reads mutable state: `!r`, `r.contents`, `r.current`, `Js.Date`,
  `Js.Math.random`, an assignment, or a variable bound by `for`/`while`;
- an expression with no free variables is constant: evaluated on mount only.

## Compiled patchers

Later, the same refresh writes to the DOM directly instead of through `put`: the ppx knows each
hole's kind and type from the DOM prop table, and walks to the nodes with `firstChild` /
`nextSibling` paths, as dartea's `find` functions do.

## Laws

Accepted only with these holding, by property-based tests:

- **Equivalence:** a guarded refresh renders the same DOM and runs the same effects as an
  unguarded one, for any component and any sequence of state and prop changes.
- **Guard soundness:** a hole is evaluated whenever one of its free variables changed.
- **Guard economy:** a hole whose free variables are all unchanged is not evaluated.
- **Volatility:** a hole that reads mutable state is evaluated on every render.
