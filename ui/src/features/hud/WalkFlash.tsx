import { useEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import "./walkflash.css";

/* A short flash at the bottom centre whenever the walk mode changes: the mode
   name, its pace and a three-cell gauge that fills with the speed. It never
   shows on connect, only on a change the player made. */

const HOLD_MS = 1600;

export function WalkFlash() {
  const walk = useStore((s) => s.hud.walk);
  const [shown, setShown] = useState<{ label: string; index: number; count: number; speed?: number; key: number } | null>(null);
  const previous = useRef<string | null | undefined>(undefined);
  const timer = useRef<number | undefined>(undefined);

  useEffect(() => {
    const mode = walk?.mode ?? null;
    if (previous.current === undefined) { previous.current = mode; return; } // first sample: nothing to announce
    if (mode === previous.current) return;
    previous.current = mode;
    if (!walk) return;
    setShown({ label: walk.label, index: walk.index ?? 1, count: walk.count ?? 3, speed: walk.speed, key: Date.now() });
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setShown(null), HOLD_MS);
    return () => window.clearTimeout(timer.current);
  }, [walk]);

  if (!shown) return null;
  // Cells fill with the pace: the first mode (run) lights them all, the last one.
  const lit = Math.max(1, shown.count - shown.index + 1);
  return (
    <div key={shown.key} className="walkflash" aria-live="polite">
      <span className="walkflash__icon"><Icon name="footprints" size={16} /></span>
      <div className="walkflash__text">
        <span className="walkflash__label">{shown.label}</span>
        <span className="walkflash__pace">{shown.speed ? `${shown.speed.toFixed(1)} M/S` : "FULL PACE"}</span>
      </div>
      <span className="walkflash__cells">
        {Array.from({ length: shown.count }, (_, i) => <span key={i} className={"walkflash__cell" + (i < lit ? " walkflash__cell--on" : "")} style={{ height: 6 + i * 5 }} />)}
      </span>
    </div>
  );
}
