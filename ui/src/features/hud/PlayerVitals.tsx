import { useEffect, useRef, useState, type CSSProperties } from "react";
import { Icon } from "@/design/components";
import { useStore } from "@/state/store";
import "./vitals.css";

const percent = (value: number, max = 100) => Number.isFinite(value) && Number.isFinite(max) && max > 0 ? Math.max(0, Math.min(100, value / max * 100)) : 0;
// A 300-degree sweep, with an opening at the bottom. All five gauges share the
// same geometry; only the health gauge is enlarged, never its stroke/text alone.
const SWEEP = "M 28.5 87.239 A 43 43 0 1 1 71.5 87.239";

/** Native samples can arrive frequently. Motion is handled by CSS, not a render loop. */
function Meter({ id, label, icon, value, max = 100, color, primary = false, warn = false, draining = false }: {
  id: string; label: string; icon: string; value: number; max?: number; color: string; primary?: boolean; warn?: boolean; draining?: boolean;
}) {
  const pct = percent(value, max);
  const rounded = Math.round(Number.isFinite(value) ? Math.max(0, value) : 0);
  const previous = useRef(rounded);
  const sequence = useRef(0);
  const [change, setChange] = useState<{ value: number; id: number } | null>(null);
  useEffect(() => {
    const difference = rounded - previous.current;
    previous.current = rounded;
    if (!primary || difference === 0) return;
    setChange({ value: difference, id: ++sequence.current });
    const timer = window.setTimeout(() => setChange(null), 1400);
    return () => window.clearTimeout(timer);
  }, [rounded, primary]);
  const progress = { strokeDashoffset: 100 - pct, opacity: pct > 0 ? 1 : 0 };
  return (
    <div data-vital={id} data-percent={pct}
      className={`player-vital${primary ? " player-vital--health" : ""}${warn ? " player-vital--low" : ""}${primary && pct <= 10 ? " player-vital--critical" : ""}${pct === 0 && !warn ? " player-vital--empty" : ""}${draining ? " player-vital--draining" : ""}`}
      style={{ "--vital-color": warn ? "#ff8278" : color } as CSSProperties}>
      <div className="player-vital__dial">
        <svg className="player-vital__gauge" viewBox="0 0 100 100" aria-hidden="true">
          <circle className="player-vital__face" cx="50" cy="50" r="36" />
          <path className="player-vital__rim" d={SWEEP} />
          <path className="player-vital__track" d={SWEEP} />
          <path className="player-vital__trail" d={SWEEP} pathLength="100" style={progress} />
          <path className="player-vital__fill" d={SWEEP} pathLength="100" style={progress} />
        </svg>
        <div className="player-vital__readout">
          <Icon className="player-vital__icon" name={icon} size={primary ? 20 : 14} />
          <span className={`player-vital__number${String(rounded).length > 3 ? " player-vital__number--compact" : ""}`}>{rounded}</span>
        </div>
        {primary && change && <span key={change.id} className={`player-vital__delta${change.value < 0 ? " is-loss" : ""}`}>{change.value > 0 ? "+" : ""}{change.value}</span>}
      </div>
      <div className="player-vital__caption"><span>{label}</span>{primary && <span className="player-vital__limit">/ {Math.round(Number.isFinite(max) && max > 0 ? max : 0)}</span>}</div>
    </div>
  );
}

export function PlayerVitals() {
  const { health, armor, stamina } = useStore((s) => s.hud);
  const needs = useStore((s) => s.state.needs);
  const lowHealth = percent(health.value, health.max) <= 25;
  const food = percent(needs.food);
  const drink = percent(needs.drink);
  const starving = needs.starving || false;
  const warnings = [lowHealth && "Low health", food <= 20 && "Hungry", drink <= 20 && "Thirsty"].filter(Boolean);
  // starving: a banner that stays as long as health drains, with how fast and how long is left
  const healthPct = percent(health.value, health.max);
  const drain = needs.drainPerMinute ?? 0;
  const minutesLeft = drain > 0 ? healthPct / drain : null;
  const what = starving === "both" ? "STARVING & DEHYDRATED" : starving === "food" ? "STARVING" : "DEHYDRATED";
  const fix = starving === "both" ? "Eat and drink now" : starving === "food" ? "Eat something now" : "Drink something now";
  const left = minutesLeft == null ? "" : minutesLeft < 1 ? "under a minute left" : `~${Math.ceil(minutesLeft)} min left`;
  // well fed: health comes back by itself (only worth showing while it is not full)
  const regen = !starving && needs.wellFed && healthPct < 100 ? needs.regenPerMinute ?? 0 : 0;
  return <div className={`player-vitals${starving ? " player-vitals--starving" : ""}`}>
    {starving && <div className="player-vitals__vignette" aria-hidden="true" style={{ "--starve-heat": Math.max(.35, 1 - healthPct / 100) } as CSSProperties} />}
    {starving ? <div className="player-vitals__starving" role="alert">
      <Icon name="heart-pulse" size={15} />
      <div><b>{what}</b><span>{drain > 0 ? `−${drain} % health / min · ` : ""}{left}{left ? " · " : ""}{fix}</span></div>
    </div>
    : warnings.length > 0 ? <div className="player-vitals__warning"><Icon name="triangle-alert" size={11} /><span>{warnings.join(" · ")}</span></div>
    : regen > 0 && <div className="player-vitals__fed"><Icon name="heart-pulse" size={11} /><span>Well fed · +{regen} HP / min</span></div>}
    <Meter id="health" label="Health" icon="heart-pulse" value={health.value} max={health.max} color="var(--accent)" primary warn={lowHealth || !!starving} draining={!!starving} />
    <div className="player-vitals__secondary">
      <Meter id="armor" label="Armor" icon="shield" value={armor} color="#bdccd9" />
      <Meter id="energy" label="Energy" icon="zap" value={percent(stamina.value, stamina.max)} color="var(--accent)" />
      <Meter id="food" label="Food" icon="apple" value={food} color="#e7b877" warn={food <= 20} draining={starving === "food" || starving === "both"} />
      <Meter id="water" label="Water" icon="droplet" value={drink} color="#72cbd5" warn={drink <= 20} draining={starving === "drink" || starving === "both"} />
    </div>
  </div>;
}
