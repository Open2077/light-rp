import { Component, StrictMode, type ErrorInfo, type ReactNode } from "react";
import { createRoot } from "react-dom/client";
import "./tokens.css";
import "./ripperdoc.css";
import { App } from "./App";
import { diag, emit } from "./bridge";

/* A render error used to unmount the whole page: the cursor stayed on screen, nothing else, and
   the server never knew (LightRP Testing, 2026-11-05). Now the error goes to the server log, the
   game gets its focus back and the app starts again, ready for the next open. */
class Recover extends Component<{ children: ReactNode }, { generation: number; failed: boolean }> {
  state = { generation: 0, failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  componentDidCatch(error: unknown, info: ErrorInfo) {
    const where = (info.componentStack ?? "").trim().split(/\r?\n/)[0]?.trim() ?? "";
    diag(`render error: ${String(error)} ${where}`);
    emit("rd:close", {});
    window.setTimeout(() => this.setState((s) => ({ generation: s.generation + 1, failed: false })), 50);
  }
  render() { return this.state.failed ? null : <App key={this.state.generation} />; }
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Recover>{null}</Recover>
  </StrictMode>,
);
