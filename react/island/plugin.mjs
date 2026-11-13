// A bundler plugin, for esbuild, for an app whose JavaScript React libraries run two ways: components of some on npm's
// React in islands (melact.island), the hooks and providers of others on melact.compat, Melact's own `react`.
//
// melact-ppx writes the import of a component bound for an island as `melact-island:<package>`, and
// melact.island imports `melact-island:react`, `melact-island:react-dom` and `melact-island:react-dom/client`.
// The plugins colour the module graph by importer: a module reached from a `melact-island:` import is in the
// island colour, where every import, `react` included, resolves as npm resolves it, and its own imports stay in
// that colour. Every other module is in the app's colour, where `react`, `react-dom` and `react/jsx-runtime`
// are melact.compat's. The two colours differ only in those imports, so a module that reaches none of them,
// directly or through its own imports, is the same in both and is bundled once, as npm bundles it: before each
// build the plugin bundles once more without writing, to learn which modules reach React. A module that reaches
// React and that both colours reach is bundled twice, each copy bound to its own React; `duplicates()` lists
// them, since a provider and the hooks that read it must be one copy.
//
//   import { esbuildColours } from "<melange output>/node_modules/melact.island/plugin.mjs";
//   const colours = esbuildColours({ compat: "<melange output>/node_modules/melact.compat" });
//   await esbuild.build({ ..., plugins: [colours.plugin] });
//   colours.duplicates(); // the modules bundled in both colours
//
// `compat` is the folder of melact.compat's emitted files (react.js, react-dom.js, react-dom-client.js,
// jsx-runtime.js).

import { readFileSync } from "node:fs";
import { dirname, extname, join } from "node:path";

const prefix = "melact-island:";

const shimmed = (compat) => ({
  react: join(compat, "react.js"),
  "react/jsx-runtime": join(compat, "jsx-runtime.js"),
  "react/jsx-dev-runtime": join(compat, "jsx-runtime.js"),
  "react-dom": join(compat, "react-dom.js"),
  "react-dom/client": join(compat, "react-dom-client.js"),
});

const bare = (source) => !source.startsWith(".") && !source.startsWith("/") && !source.startsWith("\0");

const colours = () => {
  const island = new Set();
  const app = new Set();
  return {
    seen(path, coloured) {
      (coloured ? island : app).add(path);
    },
    duplicates: () => [...island].filter((path) => app.has(path) && !/node_modules\/(react|react-dom|scheduler)\//.test(path)).sort(),
  };
};

export function esbuildColours({ compat }) {
  const shim = shimmed(compat);
  const graph = colours();
  const coloured = (seen, surveyed) => ({
    name: "melact-colours",
    setup(build) {
      const reached = { apart: () => true };
      if (surveyed === undefined)
        build.onStart(async () => {
          const importers = new Map();
          const reacting = new Set();
          const survey = (importer, path, source) => {
            if (shim[source]) reacting.add(importer);
            importers.set(path, [...(importers.get(path) ?? []), importer]);
          };
          const plugins = build.initialOptions.plugins.map((other) => (other.name === "melact-colours" ? coloured(colours(), survey) : other));
          const outcome = await build.esbuild
            .build({ ...build.initialOptions, plugins, write: false, metafile: false, logLevel: "silent" })
            .then(() => "surveyed", () => "failed");
          const queue = [...reacting];
          for (const path of queue)
            for (const importer of importers.get(path) ?? [])
              if (!reacting.has(importer)) {
                reacting.add(importer);
                queue.push(importer);
              }
          reached.apart = outcome === "surveyed" ? (path) => reacting.has(path) : () => true;
        });
      build.onResolve({ filter: /.*/ }, async (args) => {
        if (args.pluginData?.melactResolving) return undefined;
        const inIsland = args.namespace === "melact-island" || args.path.startsWith(prefix);
        const source = args.path.startsWith(prefix) ? args.path.slice(prefix.length) : args.path;
        if (!inIsland) {
          if (bare(source) && shim[source]) return { path: shim[source] };
          return undefined;
        }
        const found = await build.resolve(source, {
          kind: args.kind,
          resolveDir: args.resolveDir,
          importer: args.importer,
          pluginData: { melactResolving: true },
        });
        if (found.errors.length > 0) return { errors: found.errors };
        if (found.external || !/\.(m?js|cjs|jsx)$/.test(found.path)) return found;
        if (args.namespace === "melact-island") surveyed?.(args.importer, found.path, source);
        if (!reached.apart(found.path)) return { path: found.path };
        seen.seen(found.path, true);
        return { path: found.path, namespace: "melact-island" };
      });
      build.onLoad({ filter: /.*/, namespace: "melact-island" }, (args) => ({
        contents: readFileSync(args.path, "utf8"),
        loader: extname(args.path) === ".jsx" ? "jsx" : "js",
        resolveDir: dirname(args.path),
      }));
      build.onLoad({ filter: /\.(m?js|cjs)$/ }, (args) => {
        seen.seen(args.path, false);
        return undefined;
      });
    },
  });
  return { plugin: coloured(graph, undefined), duplicates: graph.duplicates };
}
