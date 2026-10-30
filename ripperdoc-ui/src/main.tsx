import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./tokens.css";
import "./ripperdoc.css";
import { App } from "./App";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
