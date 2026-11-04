# melact — reason-react-compatible UI compiler for Melange, no virtual DOM

Spec for implementation. Read fully before writing code. Milestones are strictly ordered;
do not start milestone N+1 until milestone N's acceptance criteria pass.

## 1. Goal

Take an existing reason-react + Melange application, swap two lines in its `dune` files
(`(libraries reason-react)` → `(libraries melact)`, `(pps reason-react-ppx)` → `(pps melact-ppx)`),
and get a build with **no React in the bundle and no virtual DOM**: JSX is compiled to DOM
templates with holes, updates write only the holes whose values changed.

The model is the one dartea uses for Elm, extended with component instances so that hooks work:

- A JSX expression evaluates to a cheap *description*: a template identity plus an array of
  hole values. Static markup never allocates per render.
- A re-render re-evaluates the component function, producing a new description, and patches
  hole by hole. "Did this hole change" is a physical-equality check (`==`, which is `===` in JS
  and therefore also value equality for strings).
- Immutable data makes this sound: an unchanged reference is an unchanged value. Mutation in
  place is invisible to the patcher, exactly as in Elm/dartea; document this.
- State updates re-render **from the component that changed**, not from the root; children
  whose props are physically unchanged are skipped.

What remains at runtime: template cloning and hole binding, the hole patcher, keyed list
reconciliation, event delegation, and per-component hook slots. No reconciler, no fiber, no
scheduler beyond "coalesce updates into one microtask", no reactive graph.

### Non-goals

- Binary compatibility with the React npm package. Third-party React components from npm,
  `react-query`, etc. will not work. Pure-OCaml reason-react code is the compatibility target.
- Suspense, concurrent rendering, `useTransition` semantics (provide inert stubs where cheap).
- Server components. SSR + hydration is milestone 6.
- Signals. There is no reactive runtime; this is deliberate.

### Fixed decisions

| Decision | Choice | Why |
|---|---|---|
| Source syntax | whatever reason-react-ppx accepts today: Reason JSX, OCaml with `[@JSX]`, and mlx (which emits `[@JSX]`) | existing projects compile unchanged |
| ppx frontend | fork of reason-react-ppx's parsing/validation (`[@react.component]`, optional props, `~key`, children, fragments); only the emission is new | battle-tested handling of the awkward cases |
| Element creation | `<template>` + `cloneNode(true)` + precomputed child paths | the actual speedup |
| Hole diff | physical equality on hole values, recursive on child holes, keyed reconcile on lists | dartea model |
| Component identity | a module-level `Type.Id`-indexed id per `[@react.component]`; props carried as a tuple, compared element-wise with `==` | typed, no `Obj`, no proxies |
| Events | delegated on `document` for the standard bubbling set; handler holes are overwritten, never diffed; `ReactEvent.*` modules wrap native events | same as reason-react's surface, Solid's cost |
| Update scheduling | `setState` marks the instance dirty; dirty instances flushed in one microtask, parent before child | React batching semantics without the machinery |

## 2. Repository layout

```
dune-project                 ; (lang dune 3.16) (using melange 0.1) mlx dialect
melact.opam  melact-ppx.opam
view/        ; lib melact.view — description type, template/hole patcher, reconcile, events. melange only.
  view.ml view.mli reconcile.ml events.ml template.ml
react/       ; lib melact — the reason-react-compatible API: React, ReactDOM, ReactEvent, ReactDOMStyle
  react.ml react.mli reactDOM.ml reactDOM.mli reactEvent.ml reactDOMStyle.ml instance.ml hooks.ml
ppx/         ; melact-ppx (ppxlib)
  frontend/  ; forked from reason-react-ppx, minimal edits
  emit.ml    ; template + holes emission
  melt_ppx.ml
program/     ; lib melact.program — Elm-style Program.sandbox/element for apps without hooks (10-line wrapper)
test/view/   ; vitest + jsdom
test/react/  ; same test suite built twice: against reason-react (real React) and against melact
test/ppx/    ; expect tests
examples/    ; counter, todomvc (reason-react's own TodoMVC, unmodified), js-framework-benchmark
compat/      ; scripts that clone reason-react's examples and build them against melact
```

## 3. Coding conventions

- Minimal, principled code. No single-use helper functions; inline them.
- Never `assert false`. Make illegal states unrepresentable with types; where a case truly cannot
  happen, restructure so the compiler agrees.
- Mutable records and arrays in `view/` and `react/instance.ml` — hot path, Melange emits good JS
  for them. GADTs and `Type.Id` where they buy a real invariant (component identity), not for show.
- `.mli` for every library module.
- `[%mel.raw]` only in `view/` for genuinely missing bindings, each with a comment saying why.
- Every milestone ends with tests passing and an example running in a browser.

## 4. Milestone 1 — `View`: descriptions, templates, holes

### Types (`view.mli`)

```ocaml
type tpl                               (* template identity + metadata; created once per JSX site *)
type child
type key = string

val tpl : html:string -> holes:hole_spec array -> tpl
(* hole_spec: Attr of path * name | Prop of path * name | Text of path | Child of path
   | Handler of path * event_name | Ref of path | Style of path | ClassList of path
   path = int list, firstChild/nextSibling steps from the clone root *)

val text   : string -> child
val empty  : child
val list   : child list -> child               (* positional reconcile *)
val keyed  : (key * child) list -> child       (* keyed reconcile *)
val tpl_instance : tpl -> hole array -> child  (* used by generated code only *)
val lazy1  : ('a -> child) -> 'a -> child      (* skipped when 'a is physically unchanged *)
val lazy2  : ('a -> 'b -> child) -> 'a -> 'b -> child
val component : 'p Instance.id -> 'p -> ('p -> child) -> child   (* milestone 2 fills this in *)

type hole =
  | HText of string
  | HAttr of string option
  | HProp : 'a -> hole                 (* value, checked, ... written as JS properties *)
  | HClass of (string * bool) list
  | HStyle of (string * string) list
  | HHandler of (Dom.event -> unit)
  | HRef of (Dom.element -> unit)
  | HChild of child

type mounted
val mount   : child -> parent:Dom.node -> before:Dom.node option -> mounted
val patch   : mounted -> child -> unit
val unmount : mounted -> unit
```

If the existential in `HProp` is a problem, make it `HProp of Js.Json.t`; do not reach for `Obj`.

### Patch algorithm

`patch m c` compares the new description `c` with what `m` holds:

- `text` vs `text`: if `s == s'` nothing, else write `.data`.
- `tpl_instance (t, h)` vs same `t`: for each hole index, if `h.(i) == h'.(i)` skip, else apply by
  hole kind (`HAttr None` removes; `HHandler` just replaces the stored closure; `HChild` recurses).
  Different `t`: unmount old, mount new in place.
- `keyed` vs `keyed`: reconcile (§ below), patching retained entries.
- `list` vs `list`: positional; patch common prefix, mount/unmount the tail.
- `lazy1 f a` vs `lazy1 f' a'`: if `f == f' && a == a'` skip entirely; else force and patch.
- `component` vs `component`: milestone 2.
- Any other pair: replace.

Holes that are children are mounted with a marker text node when siblings follow, so insertion
position is known without walking.

### Reconcile (`reconcile.ml`)

Port the udomdiff-derived algorithm Solid and dartea use: common prefix, common suffix, then map
by key for the middle; `insertBefore` against a known end marker. Must handle the benchmark
operations: create 1k/10k, append, update every 10th, swap two rows, remove one, reverse, clear.

### Events (`events.ml`)

Delegated set (as Solid): beforeinput, click, dblclick, contextmenu, focusin, focusout, input,
keydown, keyup, mousedown, mousemove, mouseout, mouseover, mouseup, pointerdown, pointermove,
pointerout, pointerover, pointerup, touchend, touchmove, touchstart. One listener per type on
`document`; handler stored on the element as a property; walk `composedPath`/parent chain.
Others: direct `addEventListener`, replaced on hole change.

### Acceptance (test/view, vitest + jsdom)

Patch cases for every pair above; reconcile operations; attribute removal; handler replacement
without DOM writes (spy on `setAttribute`); `lazy1` skipping (count forced calls); unmount
removes nodes and listeners. `examples/counter` written **by hand** against `View.*` with
`Program.sandbox` (init/update/view, no hooks) runs in a browser.

## 5. Milestone 2 — component instances and hooks (`react/`)

### Instance (`instance.ml`)

```ocaml
type 'p id                        (* wraps Type.Id.t; created once per component by the ppx *)
val id : string -> 'p id          (* name for devtools/errors only *)

type t = {
  mutable props : ...;            (* existential via the id's witness; see note *)
  slots : slot array (growable);  (* hook state, cursor reset each render *)
  mutable mounted : View.mounted option;
  parent : t option;              (* for context lookup and flush ordering *)
  mutable dirty : bool;
  mutable effects : (unit -> unit) list;  (* pending passive effects *)
  mutable layout_effects : ...;
  mutable cleanups : ...;
}
```

`View.component id props render` produces a child; on `patch` with the same `id`
(`Type.Id.provably_equal` gives the witness that props types match) compare props element-wise
(`props` is a tuple, i.e. a JS array; a single prop is still passed as a 1-tuple by the ppx):
all `==` → skip the subtree; else set props and re-render the instance in place.

### Hooks (`hooks.ml`, surfaced through `react.mli`)

Replicate reason-react's signatures exactly (0.16/0.17 line):

- `useState : (unit -> 'a) -> 'a * (('a -> 'a) -> unit)`
- `useReducer`, `useReducerWithMapState`
- `useEffect0..useEffect7`, `useLayoutEffect0..7` with reason-react's dependency-tuple signatures;
  deps compared element-wise with `==`
- `useMemo0..7`, `useCallback0..7`
- `useRef`, `useImperativeHandle*`, `useId`
- `createContext`, `useContext`, `Context.provider` — value found by walking `parent`; a provider
  change marks every consumer instance below it dirty
- `memo`, `memoCustomCompareProps` — `memo` is a no-op (component skipping is already default)
- `useTransition`, `startTransition` — inert: run synchronously
- `React.string/int/float/array/list/null/fragment`

Update semantics: a setter outside render marks the instance dirty and schedules a flush in a
microtask (`Js.Promise.resolve () |> then_`); the flush renders dirty instances parent-first,
skipping instances unmounted by a parent's render; layout effects run synchronously after each
instance's patch, passive effects after the whole flush on `requestAnimationFrame` then
`setTimeout 0` fallback. A setter during render raises with a clear message. Effect cleanups run
before re-execution and on unmount, children before parents.

### Acceptance (test/react)

The suite is written once against the reason-react API and built twice (dune `(select)` or two
`test` stanzas with different libraries/pps). Both builds must pass identical assertions:
state updates, effect ordering and cleanup, deps comparison, context propagation, child skipping
when props unchanged, refs, keys, conditional rendering, lists. Where React's and melact's observable
behaviour legitimately differs (timing of passive effects), the test asserts only the order.

## 6. Milestone 3 — `melact-ppx`

Frontend: fork `reason-react-ppx`'s handling of `[@react.component]`, props (optional, default,
`~key`, `~ref`), `children`, fragments, and the `[@JSX]` application shapes for Reason, OCaml and
mlx. Keep the fork minimal and diffable against upstream.

Emission:

1. **Lowercase tags** — collect the maximal static subtree (lowercase tags, literal attributes,
   literal children) into one `View.tpl` hoisted to module level. Dynamic attributes and child
   expressions become holes; emit `View.tpl_instance tpl [| HAttr (...); HChild (...); ... |]`.
   Attribute kind by name as reason-react does: `className`→attr `class`, `value`/`checked`→prop,
   `style`→`HStyle` (via `ReactDOMStyle`), `onClick`-style → `HHandler`, `ref`→`HRef`,
   `dangerouslySetInnerHTML` → prop `innerHTML`, `key` → consumed by the enclosing list.
   Boolean literal attributes go into the template; dynamic ones are `HAttr (Some ""|None)`.
2. **`[@react.component] let make = fun ~a ?(b=0) ~children () -> body`** →
   `let id = Instance.id "Module.make"` at module level, and
   `let make ~a ?(b=0) ~children () = View.component id (a, b, children) (fun (a, b, children) -> body)`.
   The hooks inside `body` run under the instance that `View.component` resolves to.
3. **Uppercase tags** `<Comp a=x />` → `Comp.make ~a:x ()` (unchanged from reason-react-ppx).
   Children of a component become `~children`.
4. **Fragments** → `View.list` (or `View.keyed` when every child carries `key`).
5. `React.array`/`React.list` → `View.list`; arrays whose elements carry `key` → `View.keyed`.
   Emit a build-time warning for unkeyed dynamic lists in `List.map`-shaped expressions? No —
   match React: positional unless keyed.
6. HTML-escape text and attribute literals into the template string.

Expect tests (`test/ppx`): static tree, nested holes with markers, every attribute kind,
component definition with optional/default props, component call with children, fragment, keyed
list, escaping, Reason input, mlx input.

Acceptance: `examples/counter` rewritten in reason-react style compiles with melact-ppx and matches
the hand-written milestone-1 version (one template, same hole count).

## 7. Milestone 4 — compatibility surface

Fill out the rest of the surface reason-react projects actually use:
`ReactDOM.Client.createRoot/render/hydrateRoot`, `ReactDOM.render` (deprecated but present),
`ReactDOM.createPortal`, `ReactEvent.{Synthetic,Mouse,Keyboard,Form,Focus,...}` with
`preventDefault/stopPropagation/target/currentTarget/key/...` over native events,
`ReactDOMStyle.make` and `unsafeAddProp`, `React.Ref`, `React.cloneElement` (error with message:
unsupported), `ReactDOM.domProps` as an alias shape so code that pattern-matches on it keeps compiling.

`compat/`: a script that clones `reasonml/reason-react` and `melange-re/melange-opam-template`,
rewrites `dune` files to melact, builds, and (for the TodoMVC example) runs the browser test.

Acceptance: reason-react's bundled examples and TodoMVC build unmodified and behave identically
under manual testing + the view tests from milestone 1 run against the compiled output.

## 8. Milestone 5 — performance

- `examples/js-framework-benchmark` written in reason-react style; `bench/run.sh` as in dartea
  (clone the official repo, add melact as a framework, run the official runner).
- Targets: within Solid/dartea's band on keyed results; memory within 1.5× vanilla.
- Profile and fix: hole array allocation per instance per render, `Type.Id` compare cost,
  delegated event dispatch, reconcile. Only then consider ppx-level optimisations
  (skip emitting a hole array when a template has zero dynamic holes; hoist constant holes).

## 9. Milestone 6 — SSR and hydration

`child` is a pure description, so `to_string : child -> string` is a traversal; make `view/`'s
description type and `to_string` a native-buildable library (virtual library: description +
string renderer shared, DOM patcher melange-only). Hydration: `mount` variant that binds holes to
existing nodes by path instead of cloning. Pair with server-reason-react's model for the server
half if the shapes line up; otherwise ship our own.

## 10. Milestone 7 — publish

README: the two-line migration, what is and is not supported, benchmark numbers; opam packages
`melact`, `melact-ppx`; CI running `test/view`, both builds of `test/react`, `test/ppx`, and `compat/`.

## 11. Toolchain

OCaml 5.3 (needed for `Type.Id`), Melange ≥ 5.1 (6.x preferred), dune ≥ 3.16, reason ≥ 3.13
(for the Reason-syntax tests), mlx + ocamlmerlin-mlx, ppxlib ≥ 0.34, reason-react pinned for the
dual-build tests. JS: vite for examples, vitest + jsdom for tests, no runtime npm dependencies.

## 12. Working agreement for the agent

- Each milestone: write the `.mli` and the tests first, then implement.
- `CHANGELOG.md`: one line per completed milestone.
- If a decision in this spec turns out wrong in practice, stop and explain why before deviating;
  do not silently redesign.
- Ask before adding any dependency beyond § 11.
- When a reason-react behaviour is needed that this spec does not cover, implement what
  reason-react does, not what React 19 does — the compatibility target is the OCaml surface.
