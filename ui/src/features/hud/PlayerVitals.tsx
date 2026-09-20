import { useEffect, useRef, useState, type CSSProperties } from "react";
import { Icon } from "@/design/components";
import { useStore } from "@/state/store";

const percent = (value: number, max = 100) => Number.isFinite(value) && max > 0 ? Math.max(0, Math.min(100, value / max * 100)) : 0;

/** Native samples can arrive frequently. Motion is handled by CSS, not a render loop. */
function Meter({ label, icon, value, max = 100, color, primary = false, warn = false }: {
  label: string; icon: string; value: number; max?: number; color: string; primary?: boolean; warn?: boolean;
}) {
  const pct = percent(value, max);
  const rounded = Math.round(Number.isFinite(value) ? Math.max(0, value) : 0);
  const previous = useRef(rounded);
  const [change, setChange] = useState(0);
  useEffect(() => {
    const difference = rounded - previous.current;
    previous.current = rounded;
    if (!primary || difference === 0) return;
    setChange(difference);
    const timer = window.setTimeout(() => setChange(0), 1400);
    return () => window.clearTimeout(timer);
  }, [rounded, primary]);
  return (
    <div className={`player-vital${primary ? " player-vital--health" : ""}${warn ? " player-vital--low" : ""}`}
      style={{ "--vital-color": warn ? "#ff7d78" : color } as CSSProperties}>
      <div className="player-vital__heading"><Icon name={icon} size={primary ? 16 : 13} /><span>{label}</span>
        <span className="player-vital__number">{rounded}{primary && <small> / {Math.round(max)}</small>}</span>
        {primary && change !== 0 && <span key={rounded} className={`player-vital__delta${change < 0 ? " is-loss" : ""}`}>{change > 0 ? "+" : ""}{change}</span>}
      </div>
      <div className="player-vital__track"><span className="player-vital__trail" style={{ width: `${pct}%` }} /><span className="player-vital__fill" style={{ width: `${pct}%` }} /></div>
    </div>
  );
}

export function PlayerVitals() {
  const { health, armor, stamina } = useStore((s) => s.hud);
  const needs = useStore((s) => s.state.needs);
  const lowHealth = percent(health.value, health.max) <= 25;
  const warnings = [lowHealth && "Low health", needs.food <= 20 && "Hungry", needs.drink <= 20 && "Thirsty"].filter(Boolean);
  return <div className="player-vitals">
    {warnings.length > 0 && <div className="player-vitals__warning"><Icon name="triangle-alert" size={12} />{warnings.join(" · ")}</div>}
    <Meter label="Health" icon="heart-pulse" value={health.value} max={health.max} color="var(--accent)" primary warn={lowHealth} />
    <div className="player-vitals__secondary">
      <Meter label="Armor" icon="shield" value={armor} color="#a8bfd2" />
      <Meter label="Energy" icon="zap" value={percent(stamina.value, stamina.max)} color="var(--accent)" />
      <Meter label="Food" icon="apple" value={needs.food} color="#e7c48a" warn={needs.food <= 20} />
      <Meter label="Water" icon="droplet" value={needs.drink} color="#8fc7d6" warn={needs.drink <= 20} />
    </div>
  </div>;
}
