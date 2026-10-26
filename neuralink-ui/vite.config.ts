import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Served by the Open//77 WebUI host from the resource's web/ folder. No CDN, no
// hashed names, relative URLs only: the folder is shipped as-is with the resource.
export default defineConfig({
  plugins: [react()],
  base: "./",
  resolve: { alias: { "@": "/src" } },
  build: {
    outDir: "../resources/standalone/op77_neuralink/web",
    emptyOutDir: true,
    target: "chrome120", // CEF 144 in game
    sourcemap: false,
    cssCodeSplit: false,
    assetsDir: ".",
    chunkSizeWarningLimit: 900,
    assetsInlineLimit: 0, // no data: URIs (strict CSP in game)
    rollupOptions: {
      output: {
        entryFileNames: "app.js",
        chunkFileNames: "chunk-[name].js",
        assetFileNames: (asset) => (asset.name?.endsWith(".css") ? "app.css" : "[name][extname]"),
      },
    },
  },
  server: { port: 5178, open: false },
});
