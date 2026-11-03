import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import "./mission.css";

/* While running a mission: a chip at the top of the screen with the clock. A board
   you are tagged on waits in the queue panel (features/queue/QueuePanel.tsx), like
   every other queue. */
export function MissionQueueHud() {
  const q = useStore(s => s.state.missionQueue);
  const running = q && q.running ? q : undefined;
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  useEffect(() => { setReceived(performance.now()); }, [q]);
  useEffect(() => { if (!running) return; const t = window.setInterval(() => tick(n => n + 1), 250); return () => window.clearInterval(t); }, [running]);
  if (!running) return null;
  const elapsed = performance.now() - received;
  const left = Math.max(0, Math.ceil((running.endsInMs - elapsed) / 1000));
  return <div className="mission-queue is-running" role="status">
    <span className="mission-queue__tag">MISSION</span>
    <span className="mission-queue__title">{running.title.toUpperCase()}</span>
    <span className="mission-queue__dim">{running.difficulty}</span>
    <span>{String(Math.floor(left / 60)).padStart(2, "0")}:{String(left % 60).padStart(2, "0")}</span>
    <span className="mission-queue__dim">/mission leave</span>
  </div>;
}
