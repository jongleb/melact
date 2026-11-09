#!/bin/sh
# Builds real reason-react apps against Melact by changing two lines in their dune files, then
# checks that reason-react's demo and a community TodoMVC behave exactly as they do on React.
# The apps use the recommended stanza, staged_pps with -typed; one more copy of TodoMVC keeps
# plain pps, so that the untyped path, without facts read across modules, stays checked.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work="$root/_compat"

fetch() {
  [ -d "$work/sources/$1" ] || git clone -q --depth 1 "$2" "$work/sources/$1"
}

to_melact() {
  find "$1" -name dune -exec sed -i.bak \
    -e 's/(pps \([^()]*\)reason-react-ppx\([^()]*\))/(staged_pps \1melact-ppx\2 -- -typed)/g' \
    -e 's/(libraries reason-react/(libraries melact/g' {} \;
}

to_melact_untyped() {
  find "$1" -name dune -exec sed -i.bak \
    -e 's/reason-react-ppx/melact-ppx/g' \
    -e 's/(libraries reason-react/(libraries melact/g' {} \;
}

fetch_at() {
  [ -d "$work/sources/$1" ] || {
    git init -q "$work/sources/$1"
    git -C "$work/sources/$1" fetch -q --depth 1 "$2" "$3"
    git -C "$work/sources/$1" checkout -q FETCH_HEAD
  }
}

mkdir -p "$work/sources"
fetch reason-react https://github.com/reasonml/reason-react.git
fetch melange-opam-template https://github.com/melange-re/melange-opam-template.git
fetch_at reason-todomvc https://github.com/reason-seoul/reason-todomvc.git f92ee9f4ab8026c48ac757afe2119bbeeb989582

rm -rf "$work/apps"
mkdir -p "$work/apps"
printf '(dirs apps)\n' > "$work/dune"
cp -R "$work/sources/melange-opam-template/src" "$work/apps/template"
cp -R "$work/sources/reason-react/demo" "$work/apps/demo-react"
cp -R "$work/sources/reason-react/demo" "$work/apps/demo-melact"

# reason-seoul's TodoMVC is written for reason-react 0.9 on bs-platform. The same mechanical upgrade
# to reason-react 0.17 on Melange is applied to every copy; Melact then changes only the dune file.
for app in todomvc-react todomvc-melact todomvc-melact-pps; do
  cp -R "$work/sources/reason-todomvc/src" "$work/apps/$app"
  sed -i.bak 's/ReactEvent\./React.Event./g' "$work/apps/$app"/*.re
  cat > "$work/apps/$app/Index.re" <<'EOF'
switch (ReactDOM.querySelector("#root")) {
| Some(root) => ReactDOM.Client.render(ReactDOM.Client.createRoot(root), <App />)
| None => ()
};
EOF
  cat > "$work/apps/$app/dune" <<'EOF'
(melange.emit
 (target todomvc)
 (alias melange-app)
 (module_systems
  (es6 mjs))
 (libraries reason-react melange.belt melange.dom)
 (preprocess
  (pps melange.ppx reason-react-ppx)))
EOF
done

to_melact "$work/apps/template"
to_melact "$work/apps/demo-melact"
to_melact "$work/apps/todomvc-melact"
to_melact_untyped "$work/apps/todomvc-melact-pps"
find "$work/apps" -name '*.bak' -delete

cd "$root"
dune build @_compat/apps/template/react @_compat/apps/demo-react/melange-app @_compat/apps/demo-melact/melange-app \
  @_compat/apps/todomvc-react/melange-app @_compat/apps/todomvc-melact/melange-app \
  @_compat/apps/todomvc-melact-pps/melange-app
echo "built melange-opam-template, reason-react's demo and reason-seoul's TodoMVC against Melact"

out="$root/_build/default/_compat/apps"
node "$here/compare.mjs" \
  "$out/demo-react/demo/_compat/apps/demo-react/main.mjs" \
  "$out/demo-melact/demo/_compat/apps/demo-melact/main.mjs"
node "$here/compare.mjs" --explore \
  "$out/todomvc-react/todomvc/_compat/apps/todomvc-react/Index.mjs" \
  "$out/todomvc-melact/todomvc/_compat/apps/todomvc-melact/Index.mjs"
node "$here/compare.mjs" --explore \
  "$out/todomvc-react/todomvc/_compat/apps/todomvc-react/Index.mjs" \
  "$out/todomvc-melact-pps/todomvc/_compat/apps/todomvc-melact-pps/Index.mjs"
