/* Holographic glass surface: white glass fill, inner highlight, cyan edge glow,
   scanlines, grain, a slow sheen, corner brackets and a flicker on appear. The
   game cannot be blurred behind the page, so the "glass" is all fills. */
import type { CSSProperties, ReactNode } from "react";

export interface HoloPanelProps {
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
  corners?: boolean;
  sheen?: boolean;
  tag?: string;
  flicker?: boolean;
}

export function HoloPanel({ children, className, style, corners = true, sheen = true, tag, flicker = true }: HoloPanelProps) {
  return (
    <div className={["holo", flicker && "holo--flicker", className].filter(Boolean).join(" ")} style={style}>
      <div className="holo__fx" aria-hidden>
        <span className="holo__scan" />
        {sheen && <span className="holo__sheen" />}
      </div>
      {corners && (
        <div className="holo__corners" aria-hidden>
          <i /><i /><i /><i />
        </div>
      )}
      {tag && <span className="holo__tag mono" aria-hidden>{tag}</span>}
      {children}
    </div>
  );
}

/** The little triangular pointer joining a sub-panel to the selected button. */
export function Pointer({ y, side = "left" }: { y: number; side?: "left" | "right" }) {
  return <span className={`pointer pointer--${side}`} style={{ transform: `translateY(${y}px)` }} aria-hidden />;
}
