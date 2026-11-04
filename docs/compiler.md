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
and used by both front ends. The runtime is split so that a bundle carries only what the compiled
code calls. Next: compiled patchers.

## Guards at the JSX site

The expressions inside a JSX tree only read variables in scope at the JSX site: props, state,
`let`s of the component body, parameters of an enclosing `fun`. For each hole the ppx computes
its free variables, scope-aware, from the AST. Module-qualified names (`String.length`, `Row.make`)
are constants. The ppx then emits, per template site, a refresh function:

```ocaml
View.guarded template 2 (fun block ->
  let count_changed = View.check block 0 count in          (* one === against the last count *)
  let rows_changed = View.check block 1 rows in
  View.put_handler block 0 dec;                            (* handlers: swapped, never guarded *)
  (match count_changed with
   | Unchanged -> ()
   | Changed -> View.put_text block 1 (string_of_int count));   (* evaluated only now *)
  match rows_changed with
  | Unchanged -> ()
  | Changed -> View.put_child block 2 (React.array (Array.map row rows)))
```

`View.check block k value` compares `value` with the `k`-th remembered dependency and stores
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
keyed list, template block, memo, portal, component, context provider) is a value that carries
its own code to mount itself and to patch a mounted child of its kind, and every hole is written
by its own typed `put_*`. Component instances, hook slots and the update scheduler are installed
by the first component that mounts. A bundle therefore contains only the parts its compiled code
names: Meltea's counter has no components, so it has no scheduler, no hooks and no portals.

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
