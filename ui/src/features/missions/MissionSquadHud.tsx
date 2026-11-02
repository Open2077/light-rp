import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import "./mission.css";

/* The squad frame of a running mission (raid frame): every operator, you
   included, with health, armor and life state. The server pushes it when a
   value changes (server/modules/missions.lua squadView). */
const STATE_LABEL: Record<string, string> = { down: "DOWN", dead: "DEAD", recovering: "RECOVERING" };

export function MissionSquadHud() {
  const q = useStore(s => s.state.missionQueue);
  const me = useStore(s => s.state.character?.playerId);
  if (!q || !q.running || !q.squad?.length) return null;
  return <aside className="mission-squad-hud" aria-label="Squad">
    <header><Icon name="terminal" size={12} />SQUAD<span>{q.squad.length} OPERATOR{q.squad.length > 1 ? "S" : ""}</span></header>
    {q.squad.map((m, i) => {
      const hp = m.maxHealth > 0 ? Math.max(0, Math.min(1, m.health / m.maxHealth)) : 0;
      const armor = Math.max(0, Math.min(1, m.armor / 100));
      const low = m.state === "alive" && hp < 0.3;
      return <div key={m.id} className={`mission-op is-${m.state}${low ? " is-low" : ""}${m.id === me ? " is-me" : ""}`}>
        <div className="mission-op__line">
          <span className="mission-op__index">{String(i + 1).padStart(2, "0")}{m.host && <Icon name="crown" size={10} />}</span>
          <strong>{m.name.toUpperCase()}</strong>
          {m.id === me && <em>YOU</em>}
          {STATE_LABEL[m.state] ? <span className="mission-op__state">{STATE_LABEL[m.state]}</span> : <span className="mission-op__hp">{m.health}</span>}
        </div>
        <div className="mission-op__bar is-health"><i style={{ width: `${hp * 100}%` }} /></div>
        <div className="mission-op__bar is-armor"><i style={{ width: `${armor * 100}%` }} /></div>
      </div>;
    })}
  </aside>;
}
