import { Component, type ErrorInfo, type ReactNode } from "react";

/* A feature that throws must not take the HUD down with it. The boundary logs,
   renders nothing, and tries its subtree again a moment later: App rarely re-renders,
   so waiting for new children left a feature dead for the whole session (the weapon
   wheel after one bad state, 2026-11-02). */
export class ErrorBoundary extends Component<{ name: string; children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  private retry: number | undefined;
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error(`[lightrp] ${this.props.name} crashed:`, error, info.componentStack);
    window.clearTimeout(this.retry);
    this.retry = window.setTimeout(() => this.setState({ failed: false }), 1500);
  }
  componentWillUnmount() { window.clearTimeout(this.retry); }
  componentDidUpdate(prev: { children: ReactNode }) { if (this.state.failed && prev.children !== this.props.children) this.setState({ failed: false }); }
  render() { return this.state.failed ? null : this.props.children; }
}
