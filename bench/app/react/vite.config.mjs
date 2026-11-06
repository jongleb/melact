import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import babel from "@rolldown/plugin-babel";
import react, { reactCompilerPreset } from "@vitejs/plugin-react";

const here = dirname(fileURLToPath(import.meta.url));

// REACT_COMPILER=1 adds babel-plugin-react-compiler (targeting React 18) to the same source.
export default {
  root: join(here, "../../.."),
  base: "./",
  logLevel: "silent",
  plugins: [react(), ...(process.env.REACT_COMPILER ? [babel({ presets: [reactCompilerPreset({ target: "18" })] })] : [])],
  build: {
    minify: process.env.BENCH_PROFILE ? false : "esbuild",
    emptyOutDir: true,
    rollupOptions: { input: join(here, "index.html") },
  },
};
