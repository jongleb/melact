import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import vue from "@vitejs/plugin-vue";

const here = dirname(fileURLToPath(import.meta.url));

export default {
  root: join(here, "../.."),
  base: "./",
  logLevel: "silent",
  plugins: [vue()],
  build: {
    minify: process.env.BENCH_PROFILE ? false : "esbuild",
    emptyOutDir: true,
    rollupOptions: { input: join(here, "index.html") },
  },
};
