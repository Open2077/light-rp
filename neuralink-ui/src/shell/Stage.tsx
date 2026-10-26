/* The 1920x1080 logical stage, scaled to fit the viewport (letterboxed on odd
   aspect ratios), and the root theme attributes (style, accent, intensity, motion). */
import { useEffect, useRef, type ReactNode } from "react";
import { useSettings } from "@/store/store";

export function Stage({ children }: { children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const fit = () => {
      const el = ref.current;
      if (!el) return;
      const w = window.innerWidth, h = window.innerHeight;
      const s = Math.min(w / 1920, h / 1080);
      const x = (w - 1920 * s) / 2, y = (h - 1080 * s) / 2;
      el.style.transform = `translate(${x}px, ${y}px) scale(${s})`;
      document.documentElement.style.setProperty("--stage-scale", String(s));
    };
    fit();
    window.addEventListener("resize", fit);
    return () => window.removeEventListener("resize", fit);
  }, []);
  return <div ref={ref} className="nl-stage">{children}</div>;
}

export function useRootTheme(): void {
  const settings = useSettings();
  useEffect(() => {
    const root = document.documentElement;
    root.dataset.accent = settings.accent;
    root.dataset.theme = settings.theme === "dark" ? "dark" : "light";
    root.dataset.style = settings.style === "sao" ? "sao" : "cyberpunk";
    const intensity = Math.min(1, Math.max(0.3, Number.isFinite(settings.intensity) ? settings.intensity : 0.8));
    root.style.setProperty("--intensity", intensity.toFixed(2));
  }, [settings.accent, settings.intensity, settings.theme, settings.style]);
  useEffect(() => {
    const mq = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    const apply = () => { document.documentElement.dataset.motion = mq?.matches ? "reduced" : "full"; };
    apply();
    mq?.addEventListener?.("change", apply);
    return () => mq?.removeEventListener?.("change", apply);
  }, []);
}

export function reducedMotion(): boolean {
  return document.documentElement.dataset.motion === "reduced";
}
