# melhole: a shared core, and each framework's own layer

Melact and Meltea share one runtime and one compiler. The goal is a core that holds only what both
need, with each framework's features in its own layer, so that a Meltea bundle carries nothing of
React and Meltea can specialise its loops (facts, deltas) without costing Melact a byte. Agreed with
the Melact session on 2026-11-16.

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
- **Meltea layer**: `Delta` and `View.hinting` (facts recorded by `update`), `link`/`put_linked`
  (linked handlers), `remember`, gates.
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

1. **Events.** Done: React's `onChange` tracker is `Events.delegate_tracked`, which the compiler
   emits for `onchange` and Melact's runtime calls for it. The core `delegate` delivers without it,
   so bundles without `onChange` on an input carry no tracking. Every bundle shrank, Melact's too
   (bench/meltea −131 B, Melact apps −30 to −269 B gzip).
2. **Islands out of delivery.** `until`/`resume` in the core walk become Melact's.
3. **`live` arms.** `Pure_state`, `One_keyed_state` and `Portal_state` become `Hosted` kinds or
   Melact-emitted children; measure `ab` on Melact's partial update and swap.
4. **Traversal order.** `patch_order`/`item_visits` read by `rows`/`each`/`backwards` become an
   order that Melact's loops pass, not a global the core reads.
5. **`set_prop` echoes.** The React echoes of value and checked (`Default_value`,
   `Default_checked_at_mount`, which call `Events.track`) move to a Melact prop writer.
6. **Compiler.** `Scope` takes a definition filter instead of calling `Hook_name`. After the Melact
   session's pushes of its items 3–4, in a commit of its own.
7. **Libraries.** Split `melhole` into `melhole.core` and the two layers once the code is apart.
