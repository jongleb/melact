#!/bin/sh
# Builds real reason-react apps against melact by changing two lines in their dune files,
# then checks that reason-react's demo renders and reacts to clicks exactly as it does on React.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work="$root/_compat"

fetch() {
  [ -d "$work/sources/$1" ] || git clone -q --depth 1 "$2" "$work/sources/$1"
}

to_melact() {
  find "$1" -name dune -exec sed -i.bak \
    -e 's/reason-react-ppx/melact-ppx/g' \
    -e 's/(libraries reason-react/(libraries melact/g' {} \;
}

mkdir -p "$work/sources"
fetch reason-react https://github.com/reasonml/reason-react.git
fetch melange-opam-template https://github.com/melange-re/melange-opam-template.git

rm -rf "$work/apps"
mkdir -p "$work/apps"
printf '(dirs apps)\n' > "$work/dune"
cp -R "$work/sources/melange-opam-template/src" "$work/apps/template"
cp -R "$work/sources/reason-react/demo" "$work/apps/demo-react"
cp -R "$work/sources/reason-react/demo" "$work/apps/demo-melact"

# UseReducerNoProblemo binds React's own useReducer from npm: third-party React bindings are a non-goal.
sed -i.bak '/<UseReducerNoProblemo/d' "$work/apps/demo-react/main.re" "$work/apps/demo-melact/main.re"
to_melact "$work/apps/template"
to_melact "$work/apps/demo-melact"
find "$work/apps" -name '*.bak' -delete

cd "$root"
dune build @_compat/apps/template/react @_compat/apps/demo-react/melange-app @_compat/apps/demo-melact/melange-app
echo "built melange-opam-template and reason-react's demo against melact"

out="$root/_build/default/_compat/apps"
node "$here/compare.mjs" \
  "$out/demo-react/demo/_compat/apps/demo-react/main.mjs" \
  "$out/demo-melact/demo/_compat/apps/demo-melact/main.mjs"
