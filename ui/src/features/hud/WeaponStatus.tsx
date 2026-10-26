import { Crosshair } from "lucide-react";
import { useStore } from "@/state/store";
import "./weapon-status.css";

const known = (n?: number): n is number => Number.isInteger(n) && n! >= 0;
const rounds = (n?: number) => known(n) ? String(n).padStart(2, "0") : "—";

/** Native display observations only; ammunition ownership stays in inventory. */
export function WeaponStatus() {
  const weapon = useStore(s => s.hud.weapon);
  if (!weapon?.active || !weapon.hands?.length) return null;
  return <div className="weapon-status" data-testid="weapon-hud">
    {weapon.hands.map(hand => <div key={hand.hand} className={`weapon-status__hand${hand.magazine === 0 ? " is-empty" : ""}${hand.reloading ? " is-reloading" : ""}`}>
      <Crosshair size={23} strokeWidth={1.3} />
      <div className="weapon-status__identity"><span>{hand.hand === "right" ? "RIGHT HAND" : "LEFT HAND"}{hand.reloading ? " · RELOADING" : hand.magazine === 0 ? " · EMPTY" : ""}</span><strong title={hand.label}>{hand.label}</strong>
        <div className="weapon-status__track"><i style={{width: known(hand.magazine) && known(hand.capacity) && hand.capacity > 0 ? `${Math.min(100,hand.magazine/hand.capacity*100)}%` : "0%"}} /></div>
      </div>
      <div className="weapon-status__magazine"><b>{rounds(hand.magazine)}</b><span>/ {rounds(hand.capacity)}</span></div>
    </div>)}
    <div className="weapon-status__reserve"><span>{weapon.hands.length > 1 ? "SHARED RESERVE" : "RESERVE"}</span><strong>{rounds(weapon.reserve)} <small>ROUNDS</small></strong></div>
  </div>;
}
