# Melact and Meltea: instructions for agents

Read `docs/vision.md` and `docs/compiler.md` before changing anything.

## Direction (fixed)

- **Both projects aim at Svelte.** One shared compiler sees every view at build time, turns the
  static part into a DOM template and emits per-template update code; the runtime tends to zero
  (only tree-shaken helpers: template clone, keyed moves, event delegation). Prefer generating
  code at compile time over interpreting descriptions at run time.
- **Meltea** is the Elm architecture in OCaml: model, messages, pure `update`, pure `view`,
  pure functions everywhere, views in mlx. Never add hooks or any React concept to it. It is
  the OCaml counterpart of dartea (github.com/jongleb/dartea).
- **Melact** is for code already on reason-react. It keeps pretending to be React (reason-react
  API, `[@react.component]`, hooks, two `dune` lines to migrate) and is compiled underneath the
  same way as Meltea. Compatibility is checked by `compat/run.sh` and the dual test suite.
- Guards follow dartea: each hole is guarded by `===` on the values it reads and evaluated only
  when one of them changed. This relies on pure rendering (the Rules of React; Meltea is pure).

## Working agreements

- Talk to the user in Russian; code, docs, README, figures and commits are in English.
- Write **Melact** and **Meltea** capitalized in prose; package and library identifiers stay
  lowercase (`melhole`, `melact`, `melact-ppx`, `meltea`, `meltea-ppx`, `Melhole`).
- Examples and README code use mlx.
- Commit and push when a piece is done; every commit message is exactly `wip`; never add
  Co-Authored-By or any other attribution.
- Code follows the user's OCaml design rules (`~/.claude/skills/ocaml-design`): illegal states
  unrepresentable, parse don't validate, no boolean blindness, no aliases, no single-use
  top-level helpers, no comments on functions.
- Tests are laws, not scenarios: QCheck for native code (`test/laws`), fast-check in jsdom for
  Melange code, model-based state machines, and mutation checks that every law has teeth.
- README figures (`assets/make.py`, light and dark SVG pairs) explain mechanisms only, never
  tests; refresh them after every step, render both themes and check them, keep them exact.

## Build and test

The project has its own opam switch in `_opam`.

```console
$ opam exec -- dune build
$ opam exec -- dune test                      # native laws and ppx expect tests
$ opam exec -- dune build @runtest-js && npx vitest run
$ compat/run.sh                               # real reason-react apps against Melact
```
