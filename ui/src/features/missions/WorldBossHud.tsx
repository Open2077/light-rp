import { useEffect, useState, type CSSProperties } from "react";
import { useStore } from "@/state/store";
import "./worldboss.css";

/* A world boss (server/modules/world_bosses.lua, state key worldBoss), or a staff event on
   its engine (a cyberpsycho, a gang attack: `tag`, maybe `noPay`): shown to whoever
   stands in its zone or fought it. The boss's bar, the common objective, the clock, and
   your own share against the minimum that pays; at the end, what you got and why. */
const clock = (ms: number) => {
  const s = Math.max(0, Math.ceil(ms / 1000));
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
};
const money = (n: number) => `€$ ${n.toLocaleString("en-US")}`;

export function WorldBossHud() {
  const b = useStore(s => s.state.worldBoss);
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  useEffect(() => { setReceived(performance.now()); }, [b]);
  useEffect(() => { if (!b) return; const t = window.setInterval(() => tick(n => n + 1), 500); return () => window.clearInterval(t); }, [b]);
  if (!b) return null;
  const elapsed = performance.now() - received;
  const health = Math.max(0, Math.min(1, b.bossHealth ?? 0));
  const share = Math.max(0, Math.min(100, b.share ?? 0));
  const r = b.result;
  return <section className={`wboss${b.phase !== "fight" ? " is-over" : ""}${b.inZone ? "" : " is-away"}`} role="status">
    <header>
      <span className="wboss__tag">{b.tag || "WORLD BOSS"}</span>
      <b className="wboss__name">{b.boss.toUpperCase()}</b>
      <span className="wboss__dim">{b.location}</span>
      {b.phase === "fight" && b.endsInMs != null && <span className="wboss__clock">{clock(b.endsInMs - elapsed)}</span>}
    </header>
    <div className="wboss__bar" style={{ "--hp": health } as CSSProperties}><i /><span>{Math.ceil(health * 100)} %</span></div>
    <div className="wboss__line">
      <span>{b.phase === "fight" ? `Take it down · ${b.enemiesLeft} hostile${b.enemiesLeft === 1 ? "" : "s"} · ${b.fighters} fighter${b.fighters === 1 ? "" : "s"} in the zone`
        : r ? (r.success ? `${(b.tag || "BOSS").replace(/^WORLD /, "")} DOWN` : "IT GOT AWAY") : "OVER"}</span>
      {!b.inZone && b.phase === "fight" && <span className="wboss__away">OUT OF THE ZONE</span>}
    </div>
    <div className={`wboss__share${b.eligible ? " is-eligible" : ""}`}>
      <span className="wboss__label">YOUR SHARE</span>
      <div className="wboss__meter" style={{ "--share": share / 100, "--min": (b.minShare ?? 0) / 100 } as CSSProperties}><i /><em /></div>
      <b>{share.toFixed(1)} %</b>
      <small>{b.damage.toLocaleString("en-US")} dmg · {b.kills} kill{b.kills === 1 ? "" : "s"}</small>
    </div>
    {r ? <div className={`wboss__result${r.pay > 0 ? " is-paid" : ""}`}>
      {r.pay > 0 ? <>PAID <b>{money(r.pay)}</b> · {r.share.toFixed(1)} % of the fight</>
        : b.noPay ? <>STAFF EVENT · {r.share.toFixed(1)} % of the fight, no pay</>
        : r.success ? <>NO REWARD · {r.share.toFixed(1)} % (under {b.minShare} %)</> : <>NOBODY PAID</>}
    </div>
      : <div className="wboss__hint">{b.noPay ? "Staff event: no pay, just the glory. Damage and kills still rank you."
        : b.eligible ? `Above ${b.minShare} %: you share ${money(b.reward)}.` : `Under ${b.minShare} %: no reward. Damage and kills count.`}</div>}
  </section>;
}
