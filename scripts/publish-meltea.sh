#!/bin/sh
# Exports Meltea and the core it shares with Melact, melhole, to github.com/jongleb/meltea.
# Development happens in this repository; the export is a plain snapshot, committed as "wip".
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
target=${1:-"$root/_publish/meltea"}

if [ ! -d "$target/.git" ]; then
  mkdir -p "$(dirname "$target")"
  git clone -q https://github.com/jongleb/meltea.git "$target"
fi

cd "$target"
git ls-files -z | xargs -0 rm -f
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

copy() {
  mkdir -p "$(dirname "$1")"
  cp -R "$root/$1" "$1"
}

copy melhole
copy meltea
mv meltea/examples examples
find examples -type f \( -name '*.html' -o -name '*.ml' \) -exec perl -pi -e 's|meltea/examples/|examples/|g' {} +
copy ppx/meltea
copy test/support
copy test/meltea
copy test/todomvc
perl -pi -e 's|\.\./\.\./meltea/examples/|../../examples/|g' test/todomvc/dune
copy test/served
copy test/laws
copy vite.config.js
copy test/setup.js
sed '/<!-- monorepo -->/,/<!-- \/monorepo -->/d' meltea/README.md | sed '1{/^$/d;}' > README.md
rm meltea/README.md
mkdir -p assets
cp "$root"/assets/compiled.svg "$root"/assets/compiled-dark.svg "$root"/assets/meltea.svg "$root"/assets/meltea-dark.svg \
  "$root"/assets/fields.svg "$root"/assets/fields-dark.svg "$root"/assets/selectors.svg "$root"/assets/selectors-dark.svg \
  "$root"/assets/transition.svg "$root"/assets/transition-dark.svg \
  "$root"/assets/served.svg "$root"/assets/served-dark.svg \
  "$root"/assets/fanout.svg "$root"/assets/fanout-dark.svg \
  "$root"/assets/remember.svg "$root"/assets/remember-dark.svg \
  "$root"/assets/slices.svg "$root"/assets/slices-dark.svg \
  "$root"/assets/hot.svg "$root"/assets/hot-dark.svg \
  "$root"/assets/speed.svg "$root"/assets/speed-dark.svg assets/

cat > dune-project <<'EOF'
(lang dune 3.16)

(using melange 0.1)

(name meltea)

(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (merlin_reader mlx)
  (preprocess
   (run mlx-pp %{input-file}))))

(generate_opam_files true)

(license MIT)

(authors "Gleb")

(maintainers "Gleb")

(source
 (github jongleb/meltea))

(package
 (name melhole)
 (synopsis "Templates with holes for Melange: the runtime and the compiler shared by Meltea and Melact")
 (description
  "melhole turns a view known at build time into a DOM template with holes and per-template update code, guarded by === on the values each hole reads. It is the runtime and the compiler under Meltea and Melact, and has a server writer that renders the same views to HTML natively.")
 (depends
  (ocaml (>= 5.4))
  (dune (>= 3.16))
  (melange (>= 7.0.0))
  (ppxlib (>= 0.39.0))
  ppx_deriving_variant_string
  ppx_enumerate
  (qcheck-core :with-test)))

(package
 (name meltea)
 (synopsis "The Elm architecture for Melange: pure functions, mlx views, compiled templates")
 (description
  "Meltea is the Elm architecture in OCaml: a model, messages, a pure update and a pure view written in mlx, compiled by meltea-ppx to DOM templates that re-render only what a message changed.")
 (depends
  (ocaml (>= 5.4))
  (dune (>= 3.16))
  (melange (>= 7.0.0))
  (melhole (= :version))
  (meltea-ppx (and :with-test (= :version)))
  (mlx :with-test)
  (jsonkit-melange :with-test)))

(package
 (name meltea-ppx)
 (synopsis "Meltea's mlx views with messages, compiled to templates")
 (description
  "meltea-ppx compiles Meltea's mlx views to melhole templates, reads update and view for the model fields each message changes, and can write a view's HTML natively for server rendering.")
 (depends
  (ocaml (>= 5.4))
  (dune (>= 3.16))
  (ppxlib (>= 0.39.0))
  (melhole (= :version))
  (qcheck-core :with-test)))
EOF

cat > package.json <<'EOF'
{
  "name": "meltea",
  "private": true,
  "type": "module",
  "description": "Dev-only JS tooling for Meltea's tests and examples; Meltea has no runtime npm dependencies",
  "scripts": {
    "test": "vitest run"
  },
  "devDependencies": {
    "fast-check": "3.23.2",
    "jsdom": "25.0.1",
    "vite": "5.4.11",
    "vitest": "2.1.8"
  }
}
EOF

printf '_build/\n_opam\nnode_modules\n*.install\n' > .gitignore
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  laws:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: "5.5"
      - run: opam install . --deps-only --with-test --yes
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: opam exec -- dune build
      - name: native laws and ppx expect tests
        run: opam exec -- dune test
      - name: laws in jsdom
        run: |
          opam exec -- dune build @runtest-js
          npx vitest run
      - run: opam lint *.opam
EOF
npm install --package-lock-only --ignore-scripts --no-audit --no-fund --silent
# The opam files are dune's, generated from the dune-project above; run under opam exec, or set DUNE.
"${DUNE:-dune}" build ./melhole.opam ./meltea.opam ./meltea-ppx.opam

git add -A
if git diff --cached --quiet; then
  echo "meltea: nothing to publish"
else
  git commit -q -m wip
  case "${MELTEA_PUSH:-push}" in
    push) git push -q origin HEAD && echo "meltea: published $(git rev-parse --short HEAD)" ;;
    *) echo "meltea: committed $(git rev-parse --short HEAD) locally in $target" ;;
  esac
fi
