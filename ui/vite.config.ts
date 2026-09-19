import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The page is served by the Open//77 WebUI host from the resource's web/ folder
// (manifest: web_ui_page "web/index.html", web_files { "web/**" }). No CDN, no
// hashed names, relative URLs: the folder is committed and downloaded as-is.
export default defineConfig({
  plugins: [react()],
  base: "./",
  resolve: { alias: { "@": "/src" } },
  build: {
    outDir: "../resources/gamemodes/op77_lightrp/web",
    emptyOutDir: true,
    target: "chrome120", // CEF 144 in game
    sourcemap: false,
    cssCodeSplit: false,
    assetsDir: ".",
    rollupOptions: {
      output: {
        entryFileNames: "app.js",
        chunkFileNames: "chunk-[name].js",
        assetFileNames: (asset) => (asset.name?.endsWith(".css") ? "app.css" : "[name][extname]"),
      },
    },
  },
  server: { port: 5177, open: false },
});
