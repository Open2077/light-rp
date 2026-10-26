/* Cheap ambient motes around the menu: <= 90 particles on a half-resolution
   canvas, drawn only while the interface is open and motion is allowed. */
import { useEffect, useRef } from "react";
import { reducedMotion } from "@/shell/Stage";

const COUNT = 90;
const W = 960, H = 540; // drawn at half resolution, displayed at 1920x1080

interface Mote { x: number; y: number; vx: number; vy: number; r: number; a: number; tw: number; hue: 0 | 1 }

export function Particles({ running }: { running: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas || !running || reducedMotion()) return;
    const ctx = canvas.getContext("2d", { alpha: true });
    if (!ctx) return;
    const intensity = () => Number(getComputedStyle(document.documentElement).getPropertyValue("--intensity")) || 0.8;
    const holoRgb = () => getComputedStyle(document.documentElement).getPropertyValue("--holo-rgb").trim() || "0, 229, 255";
    let k = intensity();
    let holo = holoRgb();
    // Motes gather around the menu band (x 120..900 in half-res), not the whole screen.
    const spawn = (anywhere: boolean): Mote => ({
      x: 40 + Math.random() * 880,
      y: anywhere ? Math.random() * H : H + 10,
      vx: (Math.random() - 0.5) * 0.12,
      vy: -(0.08 + Math.random() * 0.28),
      r: 0.5 + Math.random() * 1.5,
      a: 0.15 + Math.random() * 0.5,
      tw: Math.random() * Math.PI * 2,
      hue: Math.random() < 0.72 ? 0 : 1,
    });
    const motes = Array.from({ length: COUNT }, () => spawn(true));
    let raf = 0;
    let last = performance.now();
    let frame = 0;
    const draw = (now: number) => {
      raf = requestAnimationFrame(draw);
      const dt = Math.min(50, now - last) / 16.67;
      last = now;
      if (++frame % 120 === 0) { k = intensity(); holo = holoRgb(); }
      ctx.clearRect(0, 0, W, H);
      for (const m of motes) {
        m.x += m.vx * dt;
        m.y += m.vy * dt;
        m.tw += 0.03 * dt;
        if (m.y < -10) Object.assign(m, spawn(false));
        const a = m.a * (0.55 + 0.45 * Math.sin(m.tw)) * k;
        ctx.fillStyle = m.hue === 0 ? `rgba(${holo}, ${a.toFixed(3)})` : `rgba(255, 255, 255, ${(a * 0.9).toFixed(3)})`;
        ctx.beginPath();
        ctx.arc(m.x, m.y, m.r, 0, Math.PI * 2);
        ctx.fill();
      }
    };
    raf = requestAnimationFrame(draw);
    return () => { cancelAnimationFrame(raf); ctx.clearRect(0, 0, W, H); };
  }, [running]);
  return <canvas ref={ref} className="particles" width={W} height={H} aria-hidden />;
}
