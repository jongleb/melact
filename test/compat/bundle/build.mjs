// Bundles test/compat/bundle/app.mlx as an app is bundled, in Node: the reason-react build as it is, the Melact
// build coloured by melact.island's esbuild plugin. Writes both bundles and the plugin's list of modules bundled
// in both colours next to the Melange output, for test/compat/bundle.test.mjs.
import { existsSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const repo = process.cwd();
const esbuild = await import(pathToFileURL(join(repo, "node_modules/esbuild/lib/main.js")).href);
const output = (side) => join(repo, `_build/default/test/compat/bundle/${side}/output`);
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
const { esbuildColours } = await import(pathToFileURL(join(output("melact"), "node_modules/melact.island/plugin.mjs")).href);
const colours = esbuildColours({ compat: join(output("melact"), "node_modules/melact.compat") });

for (const [side, plugins] of [["react", []], ["melact", [colours.plugin]]]) {
  const built = await esbuild.build({
    entryPoints: [join(output(side), "test/compat/bundle", side, "app.mjs")],
    bundle: true,
    format: "iife",
    globalName: "App",
    write: false,
    define: { "process.env.NODE_ENV": '"production"' },
    plugins: [...plugins, melangeOutput],
    logLevel: "error",
  });
  writeFileSync(join(output(side), "bundle.js"), built.outputFiles[0].text);
}
writeFileSync(join(output("melact"), "duplicates.json"), JSON.stringify(colours.duplicates()));
