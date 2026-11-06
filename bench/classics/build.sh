#!/bin/sh
# Builds the given apps of bench/classics (all of them without arguments). Builds are serialised
# through a lock directory, because two dune processes on one _build break its lock file.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
lock="$repo/_build/classics.lock"
mkdir -p "$repo/_build"
until mkdir "$lock" 2>/dev/null; do sleep 1; done
trap 'rmdir "$lock"' EXIT INT TERM
cd "$repo"
targets=""
for app in "$@"; do targets="$targets ./bench/classics/$app"; done
opam exec -- dune build --root . ${targets:-./bench/classics}
