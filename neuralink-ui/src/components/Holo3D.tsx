/* A floating holographic slab in 3D (Night City style): the face (the panel
   itself) over stacked depth frames that give the glass its thickness, a
   blurred bloom behind, comets of light running round the cut-corner border,
   corner brackets hovering in front, a specular glint that follows the cursor
   and a local tilt toward it. Under the SAO style only the face shows.

   The face takes the panel's enter/glitch animations: anything that animates
   clip-path or filter flattens 3D, so it must never be an ancestor of the
   depth layers. --nl-c is the panel's corner cut (its own --c). */
import { useRef, type CSSProperties, type ReactNode } from "react";

export interface Holo3DProps {
  children: ReactNode;
  /** corner cut of the panel, px */
  cut?: number;
  /** number of depth frames behind the face */
  depth?: number;
  /** red accent halo instead of cyan */
  tone?: "holo" | "sel" | "ok";
  className?: string;
  faceClassName?: string;
  style?: CSSProperties;
}

export function Holo3D({ children, cut = 16, depth = 5, tone = "holo", className, faceClassName, style }: Holo3DProps) {
  const root = useRef<HTMLDivElement>(null);
  const raf = useRef(0);
  const move = (e: React.PointerEvent) => {
    const el = root.current;
    if (!el) return;
    const { clientX, clientY } = e;
    if (raf.current) return;
    raf.current = requestAnimationFrame(() => {
      raf.current = 0;
      const r = el.getBoundingClientRect();
      const lx = Math.max(-1, Math.min(1, ((clientX - r.left) / r.width) * 2 - 1));
      const ly = Math.max(-1, Math.min(1, ((clientY - r.top) / r.height) * 2 - 1));
      el.style.setProperty("--lx", lx.toFixed(3));
      el.style.setProperty("--ly", ly.toFixed(3));
      el.style.setProperty("--gx", `${((lx + 1) * 50).toFixed(1)}%`);
      el.style.setProperty("--gy", `${((ly + 1) * 50).toFixed(1)}%`);
    });
  };
  const leave = () => {
    const el = root.current;
    if (!el) return;
    el.style.setProperty("--lx", "0");
    el.style.setProperty("--ly", "0");
    el.classList.remove("is-hover");
  };
  return (
    <div
      ref={root}
      className={["nl3d", `nl3d--${tone}`, className].filter(Boolean).join(" ")}
      style={{ ...style, ["--nl-c" as string]: `${cut}px` }}
      onPointerMove={move}
      onPointerEnter={() => root.current?.classList.add("is-hover")}
      onPointerLeave={leave}
    >
      <div className="nl3d__bloom" aria-hidden />
      <div className="nl3d__depth" aria-hidden>
        {Array.from({ length: depth }, (_, i) => <i key={i} style={{ ["--k" as string]: i + 1, ["--n" as string]: depth }} />)}
      </div>
      <div className={["nl3d__face", faceClassName].filter(Boolean).join(" ")}>{children}</div>
      <div className="nl3d__glint" aria-hidden />
      <div className="nl3d__halo" aria-hidden />
      <div className="nl3d__corners" aria-hidden><i /><i /><i /><i /></div>
    </div>
  );
}
