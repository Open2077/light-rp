import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import "./objective.css";

/* An authored mission's objective (server/modules/mission_engine.lua view()):
   the tracker on the left (enemies, wave, checkpoints, team respawns) and, while
   this operator is out of the perimeter, a red warning with the countdown to death.
   Countdowns are relative to the push: the page ticks them down itself. */
const seconds = (ms: number) => Math.max(0, Math.ceil(ms / 1000));

export function MissionObjectiveHud() {
  const q = useStore(s => s.state.missionQueue);
  const objective = q && q.running ? q.objective : undefined;
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  useEffect(() => { setReceived(performance.now()); }, [objective]);
  useEffect(() => { if (!objective) return; const t = window.setInterval(() => tick(n => n + 1), 200); return () => window.clearInterval(t); }, [objective]);
  if (!objective) return null;
  const elapsed = performance.now() - received;
  const o = objective;
  let headline: string, detail: string | undefined;
  if (o.phase === "staging") { headline = "DEPLOYING"; detail = o.startsInMs != null ? `Contact in ${seconds(o.startsInMs - elapsed)} s` : undefined; }
  else if (o.kind === "waves") {
    headline = o.phase === "intermission" ? `NEXT WAVE ${Math.min((o.wave ?? 0) + 1, o.waves ?? 1)} / ${o.waves}` : `WAVE ${o.wave} / ${o.waves}`;
    detail = o.phase === "intermission" && o.nextWaveInMs != null ? `Incoming in ${seconds(o.nextWaveInMs - elapsed)} s` : `${o.enemiesLeft} hostile${o.enemiesLeft === 1 ? "" : "s"} left`;
  } else {
    const left = o.checkpoints?.filter(c => c.required && !c.reached).length ?? 0;
    headline = "CLEAR THE ZONE";
    detail = `${o.enemiesLeft} hostile${o.enemiesLeft === 1 ? "" : "s"} left${left ? ` · ${left} checkpoint${left === 1 ? "" : "s"} to reach` : ""}`;
  }
  const out = o.outOfBoundsMs != null ? seconds(o.outOfBoundsMs - elapsed) : undefined;
  const respawn = o.respawnInMs != null ? seconds(o.respawnInMs - elapsed) : undefined;
  return <>
    <aside className={`mission-objective is-${o.kind}`} aria-label="Objective">
      <header><Icon name={o.kind === "waves" ? "shield" : "crosshair"} size={12} />OBJECTIVE</header>
      <strong>{headline}</strong>
      {detail && <p>{detail}</p>}
      {o.kind === "waves" && o.waves ? <div className="mission-objective__waves">{Array.from({ length: o.waves }, (_, i) =>
        <i key={i} className={i < (o.wave ?? 0) - (o.phase === "wave" ? 1 : 0) ? "is-done" : i === (o.wave ?? 0) - 1 && o.phase === "wave" ? "is-live" : ""} />)}</div> : null}
      {o.checkpoints?.length ? <ul>{o.checkpoints.map((c, i) => <li key={i} className={c.reached ? "is-reached" : c.required ? "" : "is-optional"}>
        <Icon name={c.reached ? "check" : "map-pin"} size={11} />{c.label}{!c.required && <em>OPTIONAL</em>}</li>)}</ul> : null}
      <footer><span>KILLS {o.kills}</span><span>RESPAWNS {o.lives}</span></footer>
    </aside>
    {out != null && <div className="mission-oob" role="alert">
      <div className="mission-oob__vignette" />
      <div className="mission-oob__panel"><Icon name="triangle-alert" size={18} /><strong>LEAVING THE MISSION ZONE</strong>
        <span>Return inside the perimeter</span><b>{String(out).padStart(2, "0")}</b></div>
    </div>}
    {respawn != null && <div className="mission-respawn" role="status"><strong>DOWN</strong><span>Back in {respawn} s</span></div>}
    {o.spectating && <div className="mission-respawn is-out" role="status"><strong>OUT</strong><span>No team respawn left. Your squad fights on.</span></div>}
  </>;
}
