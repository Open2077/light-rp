/* The synaptic graph of the installation: ~64 neurons in a brain-shaped cloud,
   each linked to its nearest neighbours. From `startAt` the links light up
   outward from the implant node (graph distance), each drawn from the neuron
   that reached it, and pulses keep travelling along the lit ones. Canvas 2D,
   colours from the theme tokens; reduced motion keeps the spread, not the pulses. */
import { useEffect, useRef } from "react";
import { reducedMotion } from "@/shell/Stage";

const W = 900, H = 560;
const COUNT = 64;

interface Node { x: number; y: number; t: number; hub: boolean }
interface Edge { a: number; b: number; len: number; t0: number; t1: number; from: number }

function rng(seed: number): () => number {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

function build(): { nodes: Node[]; edges: Edge[]; origin: number } {
  const rand = rng(77);
  const nodes: Node[] = [];
  // the implant at the base of the cloud, then neurons inside two lobes
  nodes.push({ x: 250, y: 470, t: 0, hub: true });
  while (nodes.length < COUNT) {
    const x = 70 + rand() * 760, y = 50 + rand() * 440;
    const nx = (x - 470) / 400, ny = (y - 250) / 210;
    const lobe = nx * nx + ny * ny * (1 + 0.35 * nx);
    if (lobe > 1 || (y > 400 && x < 360 && x > 140)) continue;
    if (nodes.some((n) => Math.hypot(n.x - x, n.y - y) < 46)) continue;
    nodes.push({ x, y, t: Infinity, hub: false });
  }
  const key = new Set<string>();
  const edges: Edge[] = [];
  const link = (a: number, b: number) => {
    const k = a < b ? `${a}-${b}` : `${b}-${a}`;
    if (key.has(k)) return;
    key.add(k);
    edges.push({ a, b, len: Math.hypot(nodes[a]!.x - nodes[b]!.x, nodes[a]!.y - nodes[b]!.y), t0: 0, t1: 0, from: a });
  };
  nodes.forEach((n, i) => {
    const near = nodes.map((m, j) => ({ j, d: Math.hypot(m.x - n.x, m.y - n.y) })).filter((o) => o.j !== i).sort((p, q) => p.d - q.d);
    const k = i === 0 ? 4 : 3;
    for (let q = 0; q < k; q++) link(i, near[q]!.j);
  });
  const deg = new Array<number>(nodes.length).fill(0);
  edges.forEach((e) => { deg[e.a]!++; deg[e.b]!++; });
  nodes.forEach((n, i) => { if (deg[i]! >= 5) n.hub = true; });
  // Dijkstra over link lengths from the implant: when each neuron is reached
  const done = new Set<number>();
  nodes[0]!.t = 0;
  while (done.size < nodes.length) {
    let best = -1;
    nodes.forEach((n, i) => { if (!done.has(i) && (best < 0 || n.t < nodes[best]!.t)) best = i; });
    if (best < 0 || !Number.isFinite(nodes[best]!.t)) break;
    done.add(best);
    for (const e of edges) {
      if (e.a !== best && e.b !== best) continue;
      const other = e.a === best ? e.b : e.a;
      const t = nodes[best]!.t + e.len;
      if (t < nodes[other]!.t) nodes[other]!.t = t;
    }
  }
  const far = Math.max(...nodes.map((n) => (Number.isFinite(n.t) ? n.t : 0))) || 1;
  nodes.forEach((n) => { n.t = Number.isFinite(n.t) ? n.t / far : 1; });
  // a link lights from its earlier end, at the speed the front travels
  for (const e of edges) {
    const [first, second] = nodes[e.a]!.t <= nodes[e.b]!.t ? [e.a, e.b] : [e.b, e.a];
    e.from = first;
    e.t0 = nodes[first]!.t;
    e.t1 = Math.max(e.t0 + 0.04, Math.min(nodes[second]!.t, e.t0 + e.len / far));
  }
  return { nodes, edges, origin: 0 };
}

const GRAPH = build();

function rgbVar(name: string, fallback: string): string {
  const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return v || fallback;
}

/** `startAt`: ms after mount when the spread begins; `spreadMs`: how long it takes. */
export function SynapseNet({ startAt, spreadMs }: { startAt: number; spreadMs: number }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;
    const scale = Math.min(2, (window.devicePixelRatio || 1) * (Number(getComputedStyle(document.documentElement).getPropertyValue("--stage-scale")) || 1));
    canvas.width = Math.round(W * scale);
    canvas.height = Math.round(H * scale);
    ctx.setTransform(scale, 0, 0, scale, 0, 0);
    const holo = rgbVar("--holo-rgb", "0, 229, 255");
    const sel = rgbVar("--sel-rgb", "245, 197, 24");
    const calm = reducedMotion();
    const { nodes, edges } = GRAPH;
    const phase = edges.map((_, i) => (i * 0.618) % 1);
    const t0 = performance.now();
    let raf = 0;

    const draw = (now: number) => {
      const ms = now - t0;
      const p = Math.max(0, (ms - startAt) / spreadMs);
      ctx.clearRect(0, 0, W, H);
      ctx.lineCap = "round";

      // dormant mesh
      ctx.lineWidth = 1;
      ctx.strokeStyle = "rgba(255, 255, 255, 0.09)";
      ctx.beginPath();
      for (const e of edges) { const a = nodes[e.a]!, b = nodes[e.b]!; ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); }
      ctx.stroke();

      // lit links, drawn from the neuron that reached them
      ctx.globalCompositeOperation = "lighter";
      for (const e of edges) {
        if (p <= e.t0) continue;
        const k = Math.min(1, (p - e.t0) / (e.t1 - e.t0));
        const a = nodes[e.from]!, b = nodes[e.from === e.a ? e.b : e.a]!;
        const x = a.x + (b.x - a.x) * k, y = a.y + (b.y - a.y) * k;
        ctx.strokeStyle = `rgba(${holo}, 0.22)`;
        ctx.lineWidth = 5;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(x, y); ctx.stroke();
        ctx.strokeStyle = `rgba(${holo}, 0.85)`;
        ctx.lineWidth = 1.4;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(x, y); ctx.stroke();
        if (k < 1) {
          // the front: a bright head on the link being drawn
          ctx.fillStyle = "rgba(255, 255, 255, 0.95)";
          ctx.beginPath(); ctx.arc(x, y, 2.6, 0, Math.PI * 2); ctx.fill();
        }
      }

      // pulses travelling along fully lit links
      if (!calm) {
        edges.forEach((e, i) => {
          if (p < e.t1 + 0.02 || i % 2) return;
          const a = nodes[e.from]!, b = nodes[e.from === e.a ? e.b : e.a]!;
          const f = ((ms / 900) + phase[i]!) % 1;
          const x = a.x + (b.x - a.x) * f, y = a.y + (b.y - a.y) * f;
          const g = ctx.createRadialGradient(x, y, 0, x, y, 9);
          g.addColorStop(0, "rgba(255, 255, 255, 0.95)");
          g.addColorStop(0.35, `rgba(${holo}, 0.7)`);
          g.addColorStop(1, `rgba(${holo}, 0)`);
          ctx.fillStyle = g;
          ctx.beginPath(); ctx.arc(x, y, 9, 0, Math.PI * 2); ctx.fill();
        });
      }

      // neurons: dim until reached, then a pop and a steady glow (hubs in gold)
      nodes.forEach((n, i) => {
        const lit = p >= n.t;
        const age = lit ? (p - n.t) * spreadMs : 0;
        const pop = lit && !calm ? Math.max(0, 1 - age / 380) : 0;
        const rgb = n.hub ? sel : holo;
        if (lit) {
          const r = (i === 0 ? 22 : n.hub ? 15 : 10) + pop * 14;
          const g = ctx.createRadialGradient(n.x, n.y, 0, n.x, n.y, r);
          g.addColorStop(0, `rgba(${rgb}, 0.75)`);
          g.addColorStop(1, `rgba(${rgb}, 0)`);
          ctx.fillStyle = g;
          ctx.beginPath(); ctx.arc(n.x, n.y, r, 0, Math.PI * 2); ctx.fill();
        }
        ctx.fillStyle = lit ? "#fff" : "rgba(255, 255, 255, 0.28)";
        ctx.beginPath(); ctx.arc(n.x, n.y, i === 0 ? 5.5 : n.hub ? 3.6 : 2.6, 0, Math.PI * 2); ctx.fill();
      });

      // the implant: a gold ring that breathes
      const o = nodes[0]!;
      ctx.strokeStyle = `rgba(${sel}, 0.95)`;
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(o.x, o.y, 12 + (calm ? 0 : Math.sin(ms / 160) * 2), 0, Math.PI * 2); ctx.stroke();
      ctx.globalCompositeOperation = "source-over";
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [startAt, spreadMs]);

  return <canvas ref={ref} className="iseq__net" style={{ width: W, height: H }} aria-hidden />;
}
