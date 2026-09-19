import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "@/design/global.css";
import { App } from "./App";

async function boot() {
  if (!window.Open77) {
    // No game around: a browser session. The mock plays a session so the page can
    // be developed and screenshot outside Cyberpunk.
    const { installMockBridge } = await import("./dev/mock");
    installMockBridge();
  }
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <App />
    </StrictMode>,
  );
}

void boot();
