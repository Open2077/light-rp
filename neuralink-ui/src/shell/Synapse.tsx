/* Synapse links (Night City style): living fibres joining the selected column
   button to its sub-panel, and the active row (or the button) to the open
   window. The panels float on different 3D planes, so the ends are measured on
   screen every frame and drawn in stage coordinates: the fibres stay attached
   through the parallax. Each fibre: a bloom, a core, a flowing dash and two
   impulses running along it. */
import { useEffect, useRef } from "react";
import { reducedMotion } from "./Stage";

type Pt = { x: number; y: number };
const FIBRES = 2;

function curve(a: Pt, b: Pt): string {
  const dx = Math.max(30, (b.x - a.x) * 0.5);
  return `M${a.x.toFixed(1)},${a.y.toFixed(1)} C${(a.x + dx).toFixed(1)},${a.y.toFixed(1)} ${(b.x - dx).toFixed(1)},${b.y.toFixed(1)} ${b.x.toFixed(1)},${b.y.toFixed(1)}`;
}

export function Synapse() {
  const svg = useRef<SVGSVGElement>(null);
  useEffect(() => {
    const root = svg.current;
    if (!root) return;
    const groups = Array.from(root.querySelectorAll<SVGGElement>(".syn"));
    let raf = 0;
    const t0 = performance.now();
    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const stage = document.querySelector(".nl-stage");
      if (!stage) return;
      const sr = stage.getBoundingClientRect();
      const s = sr.width / 1920 || 1;
      const local = (x: number, y: number): Pt => ({ x: (x - sr.left) / s, y: (y - sr.top) / s });
      const rect = (sel: string) => { const el = document.querySelector(sel); return el ? el.getBoundingClientRect() : null; };
      const puck = rect(".column .rb.is-selected .rb__disc");
      const head = rect(".subpanel__head");
      const row = rect(".subpanel .slab.is-active");
      const win = rect(".tilt--window .nl3d__face") ?? rect(".tilt--call .nl3d__face");
      const ends: ([Pt, Pt] | null)[] = [null, null];
      if (puck && head) ends[0] = [local(puck.right + 2, puck.top + puck.height / 2), local(head.left - 2, head.top + head.height / 2)];
      const from = row ?? (head ? null : puck);
      if (from && win) {
        const y = Math.min(win.bottom - 90 * s, Math.max(win.top + 90 * s, from.top + from.height / 2));
        ends[1] = [local(from.right + 2, from.top + from.height / 2), local(win.left + 4, y)];
      }
      const time = (now - t0) / 1000;
      ends.forEach((e, i) => {
        const g = groups[i];
        if (!g) return;
        if (!e) { g.style.opacity = "0"; return; }
        g.style.opacity = "1";
        const d = curve(e[0], e[1]);
        const paths = g.querySelectorAll<SVGPathElement>("path");
        paths.forEach((p) => p.setAttribute("d", d));
        const core = paths[1]!;
        const len = core.getTotalLength();
        g.querySelectorAll<SVGCircleElement>("circle.syn__dot").forEach((c, k) => {
          const u = ((time * (0.55 + k * 0.17) + k * 0.5) % 1);
          const p = core.getPointAtLength(u * len);
          c.setAttribute("cx", p.x.toFixed(1));
          c.setAttribute("cy", p.y.toFixed(1));
          c.setAttribute("opacity", (Math.sin(u * Math.PI)).toFixed(2));
        });
        const [a, b] = g.querySelectorAll<SVGCircleElement>("circle.syn__end");
        a?.setAttribute("cx", e[0].x.toFixed(1)); a?.setAttribute("cy", e[0].y.toFixed(1));
        b?.setAttribute("cx", e[1].x.toFixed(1)); b?.setAttribute("cy", e[1].y.toFixed(1));
      });
    };
    if (!reducedMotion()) raf = requestAnimationFrame(frame);
    else frame(performance.now());
    return () => cancelAnimationFrame(raf);
  }, []);
  return (
    <svg ref={svg} className="synapse" width={1920} height={1080} viewBox="0 0 1920 1080" aria-hidden>
      <defs>
        <filter id="syn-bloom" x="-20%" y="-50%" width="140%" height="200%"><feGaussianBlur stdDeviation="4" /></filter>
      </defs>
      {Array.from({ length: FIBRES }, (_, i) => (
        <g key={i} className={`syn syn--${i}`} style={{ opacity: 0 }}>
          <path className="syn__bloom" filter="url(#syn-bloom)" />
          <path className="syn__core" />
          <path className="syn__flow" />
          <circle className="syn__end" r={3.2} />
          <circle className="syn__end" r={3.2} />
          <circle className="syn__dot" r={4} />
          <circle className="syn__dot" r={3} />
        </g>
      ))}
    </svg>
  );
}
