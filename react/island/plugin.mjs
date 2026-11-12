// A bundler plugin, for esbuild, for an app whose JavaScript React libraries run two ways: components of some on npm's
// React in islands (melact.island), the hooks and providers of others on melact.compat, Melact's own `react`.
//
// melact-ppx writes the import of a component bound for an island as `melact-island:<package>`, and
// melact.island imports `melact-island:react`, `melact-island:react-dom` and `melact-island:react-dom/client`.
// The plugins colour the module graph by importer: a module reached from a `melact-island:` import is in the
// island colour, where every import, `react` included, resolves as npm resolves it, and its own imports stay in
// that colour. Every other module is in the app's colour, where `react`, `react-dom` and `react/jsx-runtime`
// are melact.compat's. A module that both colours reach is bundled twice, each copy bound to its own React;
// `duplicates()` lists them, since a provider and the hooks that read it must be one copy.
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
  const plugin = {
    name: "melact-colours",
    setup(build) {
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
        graph.seen(found.path, true);
        return { path: found.path, namespace: "melact-island" };
      });
      build.onLoad({ filter: /.*/, namespace: "melact-island" }, (args) => ({
        contents: readFileSync(args.path, "utf8"),
        loader: extname(args.path) === ".jsx" ? "jsx" : "js",
        resolveDir: dirname(args.path),
      }));
      build.onLoad({ filter: /\.(m?js|cjs)$/ }, (args) => {
        graph.seen(args.path, false);
        return undefined;
      });
    },
  };
  return { plugin, duplicates: graph.duplicates };
}
