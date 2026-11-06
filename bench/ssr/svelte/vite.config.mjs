import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { svelte } from "@sveltejs/vite-plugin-svelte";

const here = dirname(fileURLToPath(import.meta.url));

export default {
  root: join(here, "../../.."),
  base: "./",
  logLevel: "silent",
  plugins: [svelte()],
  build: {
    minify: "esbuild",
    emptyOutDir: true,
    rollupOptions: { input: join(here, "index.html") },
  },
};
