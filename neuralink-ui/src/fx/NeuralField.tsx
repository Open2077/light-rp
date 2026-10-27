/* The neural field behind the Night City interface: neurons floating in a
   volume, projected with parallax from the shared pointer (near ones move
   more), joined to their nearest neighbours by faint synapses along which
   impulses travel, cyan and sometimes red, and now and then a neuron fires.
   On open a wave of firing sweeps out from the column to the edges.
   The centre of the screen stays clear (the player's character is there).
   Half-resolution canvas, sprites pre-rendered, nothing allocated per frame. */
import { useEffect, useRef } from "react";
import { reducedMotion } from "@/shell/Stage";
import { space } from "./space";

const W = 960, H = 540;
const COUNT = 86;
const LINKS = 3;

interface Neuron { x: number; y: number; z: number; vx: number; vy: number; ph: number; fire: number; sx: number; sy: number; a: number; wake: number }
interface Impulse { from: number; to: number; t: number; speed: number; red: boolean }

function sprite(rgb: string, size: number): HTMLCanvasElement {
  const c = document.createElement("canvas");
  c.width = c.height = size;
  const g = c.getContext("2d")!;
  const grd = g.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  grd.addColorStop(0, `rgba(255,255,255,1)`);
  grd.addColorStop(0.18, `rgba(${rgb},0.95)`);
  grd.addColorStop(0.45, `rgba(${rgb},0.28)`);
  grd.addColorStop(1, `rgba(${rgb},0)`);
  g.fillStyle = grd;
  g.fillRect(0, 0, size, size);
  return c;
}

export function NeuralField({ running }: { running: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas || !running || reducedMotion()) return;
    const ctx = canvas.getContext("2d", { alpha: true });
    if (!ctx) return;
    const cyan = sprite("46,230,245", 32), red = sprite("255,59,72", 32);

    const rnd = Math.random;
    const neurons: Neuron[] = Array.from({ length: COUNT }, () => {
      // push the neurons toward the edges: the centre column stays clear
      let x = rnd() * 2 - 1;
      x = Math.sign(x) * Math.pow(Math.abs(x), 0.6);
      const y = rnd() * 2 - 1;
      // the opening wave starts at the column (x ~ -0.4) and reaches the edges in ~1.3 s
      const wake = 0.25 + Math.hypot(x + 0.4, y * 0.6) * 0.75;
      return { x, y, z: 0.25 + rnd() * 0.75, vx: (rnd() - 0.5) * 0.012, vy: (rnd() - 0.5) * 0.01, ph: rnd() * 6.28, fire: 0, sx: 0, sy: 0, a: 0, wake };
    });
    // static topology: each neuron to its nearest neighbours (in its start layout)
    const links: [number, number][] = [];
    neurons.forEach((n, i) => {
      const near = neurons.map((m, j) => ({ j, d: (m.x - n.x) ** 2 + ((m.y - n.y) * 0.6) ** 2 + (m.z - n.z) ** 2 }))
        .filter((o) => o.j !== i).sort((a, b) => a.d - b.d).slice(0, LINKS);
      for (const o of near) if (!links.some(([a, b]) => (a === o.j && b === i) || (a === i && b === o.j))) links.push([i, o.j]);
    });
    const impulses: Impulse[] = [];
    let raf = 0, last = performance.now(), spawn = 0, age = 0;

    const frame = (now: number) => {
      const dt = Math.min(0.05, Math.max(0, (now - last) / 1000));
      last = now;
      age += dt;
      ctx.clearRect(0, 0, W, H);
      const px = space.x, py = space.y;
      for (const n of neurons) {
        n.x += n.vx * dt; n.y += n.vy * dt;
        if (n.x < -1.15 || n.x > 1.15) n.vx *= -1;
        if (n.y < -1.15 || n.y > 1.15) n.vy *= -1;
        n.fire = Math.max(0, n.fire - dt * 1.8);
        if (n.wake > 0 && age >= n.wake) { n.wake = 0; n.fire = 1; }
        // parallax: the nearer (z->1), the further it slides against the pointer
        const depth = n.z;
        n.sx = (0.5 + n.x * 0.5) * W - px * 22 * depth;
        n.sy = (0.5 + n.y * 0.5) * H - py * 13 * depth;
        const cx = Math.abs(n.sx / W - 0.5) * 2;
        // clear centre (the character), fuller at the sides
        n.a = (0.25 + 0.75 * Math.min(1, Math.max(0, (cx - 0.12) / 0.5))) * (0.35 + 0.65 * depth);
      }
      // synapses
      ctx.lineWidth = 0.6;
      for (const [a, b] of links) {
        const A = neurons[a]!, B = neurons[b]!;
        const al = Math.min(A.a, B.a) * 0.28 + Math.max(A.fire, B.fire) * 0.35;
        if (al < 0.02) continue;
        ctx.strokeStyle = `rgba(46,230,245,${al.toFixed(3)})`;
        ctx.beginPath(); ctx.moveTo(A.sx, A.sy); ctx.lineTo(B.sx, B.sy); ctx.stroke();
      }
      // neurons
      for (const n of neurons) {
        const s = (3 + n.z * 5) * (1 + n.fire * 1.6) * (0.85 + 0.15 * Math.sin(space.t * 2 + n.ph));
        ctx.globalAlpha = Math.min(1, n.a * (0.55 + n.fire));
        ctx.drawImage(n.fire > 0.5 ? red : cyan, n.sx - s, n.sy - s, s * 2, s * 2);
      }
      // impulses: spawned along random synapses, a neuron fires when one lands
      spawn -= dt;
      if (spawn <= 0 && impulses.length < 26) {
        spawn = 0.05 + rnd() * 0.12;
        const [a, b] = links[Math.floor(rnd() * links.length)]!;
        const flip = rnd() < 0.5;
        impulses.push({ from: flip ? a : b, to: flip ? b : a, t: 0, speed: 0.6 + rnd() * 0.9, red: rnd() < 0.16 });
      }
      for (let i = impulses.length - 1; i >= 0; i--) {
        const p = impulses[i]!;
        p.t += dt * p.speed;
        const A = neurons[p.from]!, B = neurons[p.to]!;
        if (p.t >= 1) {
          B.fire = Math.max(B.fire, p.red ? 1 : 0.7);
          impulses.splice(i, 1);
          // chain reaction, sometimes
          if (rnd() < 0.35 && impulses.length < 26) {
            const next = links.filter(([x, y]) => x === p.to || y === p.to);
            const l = next[Math.floor(rnd() * next.length)];
            if (l) impulses.push({ from: p.to, to: l[0] === p.to ? l[1] : l[0], t: 0, speed: p.speed, red: p.red });
          }
          continue;
        }
        const x = A.sx + (B.sx - A.sx) * p.t, y = A.sy + (B.sy - A.sy) * p.t;
        const al = Math.min(A.a, B.a) + 0.25;
        const s = p.red ? 7 : 5.5;
        ctx.globalAlpha = Math.min(1, al);
        ctx.drawImage(p.red ? red : cyan, x - s, y - s, s * 2, s * 2);
        // a short tail
        ctx.globalAlpha = Math.min(1, al * 0.4);
        const tx = A.sx + (B.sx - A.sx) * Math.max(0, p.t - 0.06), ty = A.sy + (B.sy - A.sy) * Math.max(0, p.t - 0.06);
        ctx.drawImage(p.red ? red : cyan, tx - s * 0.7, ty - s * 0.7, s * 1.4, s * 1.4);
      }
      ctx.globalAlpha = 1;
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [running]);
  return <canvas ref={ref} className="neural-field" width={W} height={H} aria-hidden />;
}
