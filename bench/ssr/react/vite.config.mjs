import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";

const here = dirname(fileURLToPath(import.meta.url));

export default {
  root: join(here, "../../.."),
  base: "./",
  logLevel: "silent",
  plugins: [react()],
  build: {
    minify: "esbuild",
    emptyOutDir: true,
    rollupOptions: { input: join(here, "index.html") },
  },
};
