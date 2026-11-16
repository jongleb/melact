# melhole: a shared core, and each framework's own layer

Melact and Meltea share one runtime and one compiler. The goal is a core that holds only what both
need, with each framework's features in its own layer, so that a Meltea bundle carries nothing of
React and Meltea can specialise its loops (facts, deltas) without costing Melact a byte. Agreed with
the Melact session on 2026-11-16.

## The rule

Meltea depends on Melact for nothing that could make it worse: not a byte, not a check at run
time, not a limit on the code its compiler may emit. Meltea's typed compiler sees the whole program
(the model's types, every change `update` makes, every read of the view), so wherever it knows more
than a general runtime path assumes, it emits its own specialised code, and takes from the core
only primitives: cloning a template, writing a hole, moving a node, delegating an event. The core
never grows a feature for one framework at the other's cost; a framework's feature is linked only
by the code that uses it.

## Layers

- **core** (`melhole`), shared by both and by nothing else: `Dom_api`, `Template`, `Witness`,
  `Reconcile`, `Keyed`, `Events` (delegation, pacing, controlled fields). Compiler: `Element` (the
  template compiler, which writes `Melhole.View.*` as a placeholder each front end binds), `Markup`,
  `Dom_props`, `Free`, `Hoist`, `Selector`, `Scope`.
- **Meltea** (`meltea.runtime`, `meltea/runtime/`): its own `View`, `Served`, `Transition`, and
  `Delta`. `meltea-ppx` rewrites the placeholder `Melhole.View`/`Served`/`Transition` of its output to
  `Meltea_runtime.*`. Its `View` has none of Melact's: no `pure`, portals, hand-written templates,
  refs, useId positions, hook order (`patch_order`, item visits) or `forget`. Every Meltea bundle
  shrank when they went: bench/meltea −146 B, the server-rendered client −226 B, TodoMVC −214 B,
  the counter −76 B.
- **Melact**: `melhole`'s `View`, `Served`, `Transition` are still where they were and are now
  Melact's alone; moving them into Melact's own library is the Melact session's to do when it suits.
  `melact.runtime` holds the rest.
- `react/meltea` (Meltea inside Melact and back) bridges the two trees: each side mounts the other's
  as a `Hosted` kind.

## Rules

- No hook through a ref on a hot path (`visit`, `front`, delivery of an event): a framework gets its
  own function, emitted by the compiler for that framework. A ref is fine where it is set once and
  read once per draw (`View.hinting`).
- `Melhole_compiler.Hook_name`, `Scope.mapper` and the fields of `Element.frontend` change only in
  commits of their own: `ppx/melact/jsx.ml` uses them.
- Everything `melhole.compiler` depends on keeps the byte mode (`test/react_open` links melact-ppx
  into a toplevel).
- Every step runs the guards of both projects and `test/team`. Steps that touch `visit`/`front`
  also run `node bench/ab.mjs --frameworks=melact --ops="partial update,swap rows"` with more rounds.

## Steps

Measured, each against `main`, sizes gzipped.

1. **Events: done.** React's `onChange` tracker is `Events.delegate_tracked`, which the compiler
   emits for `onchange` and Melact's runtime calls for it; the core `delegate` delivers without it.
   Every bundle shrank: Meltea −131 to −305 B, Melact −30 to −269 B.
2. **The Meltea layer: `melhole.meltea`.** `Delta` lives there (free: no bundle moved). Moving
   `link`/`put_linked` and `remember` out of `View` cost Meltea +3 to +14 B for no gain, so they
   stay in `View`; Melact never links them.
3. **Melact-only code stays where it is, linked only by Melact.** Moving the `onChange` tracker
   into `melact.runtime` cost each Melact app with `onChange` +38 to +50 B; moving the patch order
   (`patch_order`, item visits) behind an `ordering` record saved Meltea 3 B and cost Melact +20 to
   +115 B. Neither is worth it: Meltea already links none of it. The same holds for refs, `pure`,
   portals and useId until a measurement says otherwise.
4. **What still costs Meltea is not Melact's but general:** the hydration medium in bundles that
   never hydrate (about 600 B minified), the parts of `View.rows` a loop does not use, and nested
   templates for view helpers. These are the Meltea roadmap's steps 5, 4 and 6, and the deltas track
   (per-message draws from what `update` did) goes past them: code emitted per program, not paths
   chosen at run time.
5. **Compiler.** `Scope` takes a definition filter instead of calling `Hook_name`, in a commit of
   its own, when Meltea needs it.
