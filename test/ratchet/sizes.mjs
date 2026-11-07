// The size ratchet: the gzip -9 size of every production bundle of Melact and Meltea code that the
// repository builds (bench/melact, bench/meltea, the hydrating clients of bench/ssr, the apps of
// bench/classics under Melact, the examples), bundled by esbuild the way bench/classics/run.mjs
// bundles. test/ratchet/sizes.json keeps the recorded sizes; the law test fails when one grows.
//
//   node test/ratchet/sizes.mjs                          compare with the baseline
//   node test/ratchet/sizes.mjs --lower                  record the bundles that got smaller
//   node test/ratchet/sizes.mjs --allow-growth=<reason>  record growth the user approved, with the reason
//   node test/ratchet/sizes.mjs --admit=<bundle>         record a bundle new to the ratchet (--admit=* for all)
//
// Run `opam exec -- dune build` first: the bundles are made from the Melange output in _build.
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { gzipSync } from "node:zlib";

const baselinePath = "test/ratchet/sizes.json";
const output = (dir) => `_build/default/${dir}/output/${dir}`;
const classics = readdirSync("bench/classics")
  .filter((app) => existsSync(`bench/classics/${app}/scenario.mjs`) && existsSync(`bench/classics/${app}/app.mlx`))
  .sort();

export const bundles = () => ({
  "bench/melact": `${output("bench/melact")}/main.mjs`,
  "bench/meltea": `${output("bench/meltea")}/main.mjs`,
  "bench/ssr/melact client": `${output("bench/ssr/melact/client")}/main.mjs`,
  "bench/ssr/meltea client": `${output("bench/ssr/meltea/client")}/main.mjs`,
  "examples/counter": `${output("examples/counter")}/main.mjs`,
  "examples/todomvc": `${output("examples/todomvc")}/main.mjs`,
  ...Object.fromEntries(classics.map((app) => [`bench/classics/${app}`, `${output(`bench/classics/${app}/melact`)}/app.mjs`])),
});

export const measure = async () => {
  const esbuild = await import(pathToFileURL(join(process.cwd(), "node_modules/esbuild/lib/main.js")).href);
  const melangeOutput = {
    name: "melange-output",
    setup(build) {
      build.onResolve({ filter: /^[^./]/ }, ({ path, importer }) => {
        const found = importer.match(/^(.*\/_build\/default\/.*?\/output)\//);
        if (!found) return null;
        const candidate = join(found[1], "node_modules", path);
        return existsSync(candidate) ? { path: candidate } : null;
      });
    },
  };
  const sizes = {};
  for (const [name, entry] of Object.entries(bundles())) {
    if (!existsSync(entry)) throw new Error(`${entry} is not built; run opam exec -- dune build`);
    const built = await esbuild.build({
      entryPoints: [join(process.cwd(), entry)],
      bundle: true,
      format: "esm",
      minify: true,
      write: false,
      define: { "process.env.NODE_ENV": '"production"' },
      plugins: [melangeOutput],
      logLevel: "error",
    });
    sizes[name] = gzipSync(built.outputFiles[0].contents, { level: 9 }).length;
  }
  return sizes;
};

export const recorded = () => (existsSync(baselinePath) ? JSON.parse(readFileSync(baselinePath, "utf8")) : { sizes: {}, growth: [] });

export const verdicts = (measured, baseline) => [
  ...Object.entries(measured).flatMap(([name, now]) => {
    const was = baseline.sizes[name];
    if (was === undefined) return [{ kind: "unrecorded", name, now }];
    if (now > was) return [{ kind: "grown", name, was, now }];
    if (now < was) return [{ kind: "shrunk", name, was, now }];
    return [];
  }),
  ...Object.keys(baseline.sizes)
    .filter((name) => !(name in measured))
    .map((name) => ({ kind: "dropped", name })),
];

export const shown = (verdict) =>
  verdict.kind === "grown"
    ? `↑ ${verdict.name}: ${verdict.was} → ${verdict.now} bytes (+${verdict.now - verdict.was})`
    : verdict.kind === "shrunk"
      ? `↓ ${verdict.name}: ${verdict.was} → ${verdict.now} bytes (−${verdict.was - verdict.now})`
      : verdict.kind === "unrecorded"
        ? `+ ${verdict.name}: ${verdict.now} bytes, not in ${baselinePath} yet`
        : `- ${verdict.name}: in ${baselinePath}, no longer built`;

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const option = (name) => process.argv.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
  const admitted = process.argv.filter((arg) => arg.startsWith("--admit=")).map((arg) => arg.slice("--admit=".length));
  const reason = option("allow-growth");
  const lowering = process.argv.includes("--lower");
  const measured = await measure();
  const baseline = recorded();
  const found = verdicts(measured, baseline);
  for (const verdict of found) console.log(shown(verdict));
  if (found.length === 0) console.log(`all ${Object.keys(measured).length} bundles are the size ${baselinePath} records`);
  const grown = found.filter((verdict) => verdict.kind === "grown");
  const unrecorded = found.filter((verdict) => verdict.kind === "unrecorded" && !admitted.includes(verdict.name) && !admitted.includes("*"));
  const dropped = found.filter((verdict) => verdict.kind === "dropped");
  if (!lowering && !reason && admitted.length === 0) process.exit(grown.length + unrecorded.length + dropped.length > 0 ? 1 : 0);
  if (grown.length > 0 && !reason) {
    console.error("\nRefusing to record: a bundle grew. Growth needs the user's approval: --allow-growth=<reason>.");
    process.exit(1);
  }
  if (unrecorded.length > 0 || dropped.length > 0) {
    console.error("\nRefusing to record: a bundle is new (--admit=<bundle>) or no longer built (remove it from the baseline by hand).");
    process.exit(1);
  }
  const growth = reason
    ? [
        ...baseline.growth,
        {
          date: new Date().toISOString().slice(0, 10),
          reason,
          grown: Object.fromEntries(grown.map((verdict) => [verdict.name, [verdict.was, verdict.now]])),
        },
      ]
    : baseline.growth;
  const sizes = Object.fromEntries(
    Object.entries(measured).map(([name, now]) => [name, reason || !(name in baseline.sizes) ? now : Math.min(now, baseline.sizes[name])]),
  );
  writeFileSync(baselinePath, JSON.stringify({ sizes, growth }, null, 2) + "\n");
  console.log(`\nwrote ${baselinePath}`);
}
