import { defineConfig } from "vite";

// The page is served from the resource's virtual origin: every URL stays relative.
export default defineConfig({
  base: "./",
  build: {
    outDir: "../web",
    emptyOutDir: true,
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 1500,
    target: "es2022",
  },
});
