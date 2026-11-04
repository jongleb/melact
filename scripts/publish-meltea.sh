#!/bin/sh
# Exports Meltea and the core it shares with Melact, mehole, to github.com/jongleb/meltea.
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

copy mehole
copy meltea
copy ppx/meltea
copy examples/counter
copy test/support
copy test/meltea
copy test/laws
copy vite.config.js
copy test/setup.js
mv meltea/README.md README.md
mkdir -p assets
cp "$root"/assets/loop.svg "$root"/assets/loop-dark.svg assets/

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
 (name mehole)
 (synopsis "Templates with holes for Melange: the runtime and the compiler shared by Meltea and Melact")
 (depends
  (ocaml (>= 5.3))
  (dune (>= 3.16))
  (melange (>= 5.1))
  (ppxlib (>= 0.34))
  ppx_deriving_variant_string
  ppx_enumerate
  (qcheck-core :with-test)))

(package
 (name meltea)
 (synopsis "The Elm architecture for Melange: pure functions, mlx views, compiled templates")
 (depends
  (ocaml (>= 5.3))
  (dune (>= 3.16))
  (melange (>= 5.1))
  mehole
  (mlx :with-test)))

(package
 (name meltea-ppx)
 (synopsis "mlx views with messages, compiled to templates, for Meltea")
 (depends
  (ocaml (>= 5.3))
  (dune (>= 3.16))
  (ppxlib (>= 0.34))
  mehole))
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

printf '_build/\n_opam/\nnode_modules/\n*.install\n' > .gitignore
cp "$root"/mehole.opam "$root"/meltea.opam "$root"/meltea-ppx.opam .

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
