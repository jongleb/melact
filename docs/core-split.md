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

- **core** (shared by both):
  - templates and holes;
  - `Reconcile` and keyed moves;
  - `Dom_api`;
  - event delegation: bubbling, disabled elements, pacing, controlled fields;
  - the `View` core: `compiled`/`static`, text/list/keyed, `rows`/`each` with selectors and pieces,
    `memo`, `chunks`, the `Hosted` extension point, `Transition`;
  - the deferred-write queue (`written`/`attach_later`; `<select>` values need it, not only refs).
  - Compiler: `Element`, `Markup`, `Free`, `Hoist`, `Selector`, a `Scope` without hooks, a neutral
    `Dom_props`.
  - An optional hydration layer (medium, `adopt_*`, `served_*`, `Served`) that only programs that
    hydrate link.
- **Meltea layer** (`melhole.meltea`): `Delta`, the facts `update` records, which install
  `View.hinting`. `link`/`put_linked` (linked handlers) and `remember` stay in `View` (see step 2);
  only Meltea links them.
- **Melact layer**:
  - refs (`reference_hole`, `set_reference`);
  - the traversal order for hooks (`patch_order`, item visits);
  - React's `onChange` value tracker;
  - islands (`segment`, `resume_at`, `until`/`resume`);
  - portal and `pure` as `Hosted` kinds;
  - recovery after a throw (`Recovers`, `forget`);
  - useId (`positions`, `Tree_ids`, `adopt_forked`);
  - `items`/`Deferred`, `put_handler` (closure handlers);
  - `Hook_name`, `react_name`.
- `react/meltea` (Meltea inside Melact) stays above both.

Checked against the code, not part of the Melact layer:
- the `written` queue: `set_prop` uses it for `<select>` values;
- controlled fields: Meltea's TodoMVC uses `controlled_hole`, and the deltas' guarantee rests on
  them;
- `lazy1`, `lazy2`, `tpl_instance`: the loop and view laws use them.

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
