# Melact and Meltea

Two front ends, one compiler, a runtime that tends to zero.

## Meltea

The Elm architecture in OCaml: a model, messages, a pure `update`, a pure `view`. No hooks, no
stateful components, pure functions everywhere. Views are written in mlx, for the looks:

```ocaml
let view count =
  <div className="counter">
    <button onClick=Decrement>(Html.text "-")</button>
    <output>(Html.int count)</output>
    <button onClick=Increment>(Html.text "+")</button>
  </div>
```

It is to OCaml what [dartea](https://github.com/jongleb/dartea) is to Elm: the same architecture,
compiled so that there is no virtual DOM and almost no runtime.

## Melact

For code that already lives on reason-react. Melact still pretends to be React: the same
`React.useState`, the same `[@react.component]`, the same JSX, two lines changed in `dune`.
Underneath it is compiled the way Meltea is, and it aims at the same small runtime.

## The compiler, shared

Both are compiled like Svelte: the compiler sees the shape of every view at build time.

- The static part of a view becomes a DOM template, parsed once and cloned.
- Every dynamic part becomes a hole with a direct path to its DOM node.
- For every template the compiler emits the update code itself: each hole is guarded by the
  values it reads (one `===` each, as in dartea), evaluated only when one of them changed, and
  written straight to its node.
- Immutable values make the guards sound: an unchanged reference is an unchanged value.

## The runtime, towards zero

What remains at run time is what the compiled code calls, and only that, tree-shaken:
cloning a template, moving keyed rows with the fewest DOM moves, delegating events. No virtual
DOM, no tree diff, no interpreter over descriptions, no reactive graph. Melact adds hook slots
and a microtask scheduler, because React's semantics need them; Meltea does not.

## Layout

```
melhole/runtime     melhole           shared runtime: templates, guards, keyed moves, events
melhole/compiler    melhole.compiler  shared compiler: templates, scopes, guards, DOM props
ppx/melact         melact-ppx       JSX, [@react.component], hook keys
ppx/meltea         meltea-ppx       mlx views with messages
react/             melact           React, ReactDOM, ReactEvent
meltea/            meltea           Program (sandbox, element), Cmd, Sub, Html
```

Meltea depends on `melhole` only. It is mirrored to github.com/jongleb/meltea by
`scripts/publish-meltea.sh`; development happens here.
