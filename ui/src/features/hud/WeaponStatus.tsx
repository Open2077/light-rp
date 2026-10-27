import { Crosshair } from "lucide-react";
import type { CSSProperties } from "react";
import { useStore } from "@/state/store";
import "./weapon-status.css";
const known = (n?: number): n is number => Number.isInteger(n) && n! >= 0;
const rounds = (n?: number) => known(n) ? String(n).padStart(2, "0") : "—";
const SWEEP = "M 28.5 87.239 A 43 43 0 1 1 71.5 87.239";
export function WeaponStatus() {
  const weapon = useStore(s => s.hud.weapon);
  if (!weapon?.active || !weapon.hands?.length) return null;
  return <div className="weapon-status" data-testid="weapon-hud">
    <div className="weapon-status__hands">{weapon.hands.map(hand => {
      const pct=known(hand.magazine)&&known(hand.capacity)&&hand.capacity>0?Math.min(100,hand.magazine/hand.capacity*100):0;
      return <div key={hand.hand} className={`player-vital weapon-status__hand${hand.magazine===0?" is-empty":""}`} style={{"--vital-color":hand.magazine===0?"#ff8278":"var(--accent)"}as CSSProperties}>
        <div className="player-vital__dial"><svg className="player-vital__gauge" viewBox="0 0 100 100"><circle className="player-vital__face" cx="50" cy="50" r="36"/><path className="player-vital__rim" d={SWEEP}/><path className="player-vital__track" d={SWEEP}/><path className="player-vital__fill" d={SWEEP} pathLength="100" style={{strokeDashoffset:100-pct,opacity:pct>0?1:0}}/></svg>
          <div className="player-vital__readout"><Crosshair className="player-vital__icon"/><b className="player-vital__number">{rounds(hand.magazine)}</b></div>
          {hand.reloading&&<span className="weapon-status__reload">RELOADING</span>}
        </div>
        <div className="player-vital__caption"><span>{hand.hand==="right"?"R":"L"}</span><span className="player-vital__limit">/ {rounds(hand.capacity)}</span></div>
        <span className="weapon-status__name" title={hand.label}>{hand.label}</span>
      </div>;
    })}</div>
    <div className="weapon-status__reserve"><span>{weapon.hands.length>1?"SHARED RESERVE":"RESERVE"}</span><strong>{rounds(weapon.reserve)}</strong><small>ROUNDS</small></div>
  </div>;
}
