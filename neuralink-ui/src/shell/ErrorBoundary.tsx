import { Component, type ErrorInfo, type ReactNode } from "react";

/* A render crash must not leave a stuck invisible surface over the game: log it
   and render nothing until the next state. */
export class ErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("[neuralink] render failed", error, info.componentStack);
    window.setTimeout(() => this.setState({ failed: false }), 1500);
  }
  render() { return this.state.failed ? null : this.props.children; }
}
