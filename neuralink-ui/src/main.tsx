import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "@/styles/tokens.css";
import "@/styles/base.css";
import "@/styles/sao.css";
import "@/styles/shell.css";
import "@/styles/apps.css";
import "@/styles/social.css";
import "@/styles/call.css";
import "@/styles/toasts.css";
import "@/styles/implant.css";
import "@/styles/cyberpunk.css";
import { App } from "./App";
import { ErrorBoundary } from "./shell/ErrorBoundary";

async function boot() {
  if (!window.Open77) {
    // A plain browser (vite dev, screenshots): the mock plays a session.
    const { installMockBridge } = await import("./bridge/mock");
    installMockBridge();
  }
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <ErrorBoundary>
        <App />
      </ErrorBoundary>
    </StrictMode>,
  );
}

void boot();
