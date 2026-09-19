import { Component, type ErrorInfo, type ReactNode } from "react";

/* A feature that throws must not take the HUD down with it. The boundary logs
   and renders nothing until the next successful render of its subtree. */
export class ErrorBoundary extends Component<{ name: string; children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  componentDidCatch(error: Error, info: ErrorInfo) { console.error(`[lightrp] ${this.props.name} crashed:`, error, info.componentStack); }
  componentDidUpdate(prev: { children: ReactNode }) { if (this.state.failed && prev.children !== this.props.children) this.setState({ failed: false }); }
  render() { return this.state.failed ? null : this.props.children; }
}
