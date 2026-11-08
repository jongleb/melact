#!/bin/sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
work="${JFB:-$HOME/.cache/melact-jfb}"
commit="${JFB_COMMIT:-fa510a76ffe066af1d30f3e75fa51d3fcbc14009}"
port="${PORT:-8080}"
frameworks="${FRAMEWORKS:-vanillajs meltea melact react-hooks react-hooks-18 svelte vue-vapor solid inferno elm ivi}"
max_load="${MAX_LOAD:-3}"
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
keyed="$work/frameworks/keyed"
steps="${*:-build bench results}"
step() { case " $steps " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

if [ ! -d "$work" ]; then
  git clone https://github.com/krausest/js-framework-benchmark.git "$work"
  git -C "$work" checkout -q "$commit"
  (cd "$work" && npm ci --legacy-peer-deps && npm run install-local)
fi

if step build; then
  (cd "$repo" && opam exec -- dune build --root . ./bench/meltea ./bench/melact)
  for f in $frameworks; do
    case "$f" in
      meltea | melact)
        rm -rf "$keyed/$f"
        mkdir -p "$keyed/$f"
        cp "$here/$f/package.json" "$here/$f/package-lock.json" "$keyed/$f/"
        cp "$repo/_build/default/bench/$f/prerendered/index.html" "$keyed/$f/index.html"
        cp -R "$repo/_build/default/bench/$f/prerendered/output" "$keyed/$f/output"
        chmod -R u+w "$keyed/$f/output" "$keyed/$f/index.html"
        (cd "$keyed/$f" && npm ci && npm run build-prod)
        ;;
      react-hooks-18)
        rm -rf "$keyed/$f"
        mkdir -p "$keyed/$f"
        (cd "$keyed/react-hooks" && cp -R package.json package-lock.json index.html webpack.config.js src "$keyed/$f/")
        (cd "$keyed/$f" && npm install --save-exact react@18.3.1 react-dom@18.3.1 && npm run build-prod)
        ;;
      elm)
        (cd "$keyed/$f" && npm ci && npm install --no-save elm-tooling && npm run build-prod)
        ;;
      *)
        (cd "$keyed/$f" && npm ci && npm run build-prod)
        ;;
    esac
  done
fi

if step bench || step results; then
  (cd "$work/server" && PORT="$port" exec node_modules/.bin/tsx index.ts) > "$work/server.log" 2>&1 &
  server=$!
  trap 'kill $server 2>/dev/null || true' EXIT INT TERM
  until curl -sf "http://localhost:$port/ls" > /dev/null; do sleep 1; done
fi

if step bench; then
  (cd "$work/webdriver-ts" && PORT="$port" npm run isKeyed -- --headless --chromeBinary "$chrome" \
    --framework $(for f in $frameworks; do printf "keyed/%s " "$f"; done))
  for f in $frameworks; do
    waited=0
    while [ "$(sysctl -n vm.loadavg | awk '{ print int($2) }')" -ge "$max_load" ] && [ "$waited" -lt 30 ]; do
      echo "load $(sysctl -n vm.loadavg), waiting before $f"
      sleep 60
      waited=$((waited + 1))
    done
    echo "load $(sysctl -n vm.loadavg), running $f"
    (cd "$work/webdriver-ts" && PORT="$port" npm run bench -- --headless --chromeBinary "$chrome" \
      --framework "keyed/$f" ${BENCHMARKS:+--benchmark $BENCHMARKS})
  done
fi

if step results; then
  (cd "$work/webdriver-ts" && PORT="$port" npm run results)
  mkdir -p "$here/results"
  cp "$work"/webdriver-ts/results/*.json "$work/webdriver-ts/results.json" "$here/results/"
  (cd "$work/webdriver-ts" && PORT="$port" CHROME="$chrome" OUT="$here/result.png" node --input-type=module -e '
import puppeteer from "puppeteer-core";
const browser = await puppeteer.launch({
  executablePath: process.env.CHROME,
  args: ["--headless=new"],
  defaultViewport: { width: 1400, height: 1000, deviceScaleFactor: 2 },
});
const page = await browser.newPage();
await page.goto(`http://localhost:${process.env.PORT}/webdriver-ts-results/dist/index.html`, { waitUntil: "networkidle0" });
await page.screenshot({ path: process.env.OUT, fullPage: true });
await browser.close();
')
  echo "results: $here/results, screenshot: $here/result.png"
fi
