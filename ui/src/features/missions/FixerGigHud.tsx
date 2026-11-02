import { useEffect, useState, type CSSProperties } from "react";
import { useStore } from "@/state/store";
import "./mission.css";

/* A fixer gig taken, before it runs (server/modules/fixers.lua, state key fixerGig):
   the chip at the top of the screen, like a tagged board. The crew meets at the
   point the fixer pinned; the chip counts who is there and the meeting clock, then
   the launch countdown. Once the gig runs, the mission chip takes over. */
export function FixerGigHud() {
  const g = useStore(s => s.state.fixerGig);
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  useEffect(() => { setReceived(performance.now()); }, [g]);
  useEffect(() => { if (!g) return; const t = window.setInterval(() => tick(n => n + 1), 250); return () => window.clearInterval(t); }, [g]);
  if (!g) return null;
  const elapsed = performance.now() - received;
  const clock = (ms?: number) => {
    if (ms == null) return "--:--";
    const s = Math.max(0, Math.ceil((ms - elapsed) / 1000));
    return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
  };
  const countdown = g.state === "countdown" && g.launchInMs != null ? Math.max(0, Math.ceil((g.launchInMs - elapsed) / 1000)) : undefined;
  const missing = g.crew - g.here;
  return <div className={`mission-queue is-gig${countdown != null ? " is-countdown" : ""}`} role="status">
    <span className="mission-queue__tag">GIG</span>
    <span className="mission-queue__title">{g.title.toUpperCase()}</span>
    <span className="mission-queue__dim">{g.fixer}</span>
    <span className="mission-queue__count">{countdown != null ? `STARTING IN ${String(countdown).padStart(2, "0")}`
      : missing > 0 ? `AT THE MEET ${g.here}/${g.crew} · ${clock(g.meetInMs)}` : `CREW ${g.crew}/${g.max}${g.crew < g.min ? ` · NEED ${g.min - g.crew}` : ""}`}</span>
    <div className="mission__meter is-standard" style={{ "--cells": g.max } as CSSProperties}>
      {Array.from({ length: g.max }, (_, i) => <i key={i} className={i < g.here ? "is-on" : i < g.crew ? "is-half" : ""} />)}</div>
  </div>;
}
