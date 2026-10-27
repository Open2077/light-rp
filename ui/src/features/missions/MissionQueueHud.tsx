import { useEffect, useState, type CSSProperties } from "react";
import { useStore } from "@/state/store";
import "./mission.css";

/* While tagged on a board (anywhere near the point) or running a mission: a chip
   at the top of the screen with the board's fill, the countdown, or the clock. */
export function MissionQueueHud() {
  const q = useStore(s => s.state.missionQueue);
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  useEffect(() => { setReceived(performance.now()); }, [q]);
  useEffect(() => { if (!q) return; const t = window.setInterval(() => tick(n => n + 1), 250); return () => window.clearInterval(t); }, [q]);
  if (!q) return null;
  const elapsed = performance.now() - received;
  if (q.running) {
    const left = Math.max(0, Math.ceil((q.endsInMs - elapsed) / 1000));
    return <div className="mission-queue is-running" role="status">
      <span className="mission-queue__tag">MISSION</span>
      <span className="mission-queue__title">{q.title.toUpperCase()}</span>
      <span className="mission-queue__dim">{q.difficulty}</span>
      <span>{String(Math.floor(left / 60)).padStart(2, "0")}:{String(left % 60).padStart(2, "0")}</span>
      <span className="mission-queue__dim">/mission leave</span>
    </div>;
  }
  const countdown = q.state === "countdown" && q.countdownMs != null ? Math.max(0, Math.ceil((q.countdownMs - elapsed) / 1000)) : undefined;
  const need = Math.max(0, q.min - q.count);
  const tone = q.difficultyId === "hard" ? "hard" : q.difficultyId === "critical" ? "critical" : "standard";
  return <div className={`mission-queue${countdown != null ? " is-countdown" : ""}`} role="status">
    <span className="mission-queue__tag">TAGGED</span>
    <span className="mission-queue__title">{q.title.toUpperCase()}</span>
    <span className="mission-queue__dim">{q.difficulty}</span>
    <span className="mission-queue__count">{countdown != null ? `LAUNCHING IN ${String(countdown).padStart(2, "0")}` : `${q.count}/${q.max}${need > 0 ? ` · NEED ${need} MORE` : q.count < q.max ? " · FILLING" : ""}`}</span>
    <div className={`mission__meter is-${tone}`} style={{ "--cells": q.max } as CSSProperties}>
      {Array.from({ length: q.max }, (_, i) => <i key={i} className={i < q.count ? "is-on" : ""} />)}</div>
  </div>;
}
