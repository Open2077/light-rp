import { ArrowUp, Bomb, CircleDot, Crosshair, Pill, RotateCw, Swords } from "lucide-react";
import { Icon } from "@/design/components";
import { useStore } from "@/state/store";
import "./safezone-status.css";

/** Lives inside the gameplay HUD, so creation and tutorial visibility stay consistent. */
export function SafezoneStatus() {
  const zone = useStore(state => state.safezone);
  if (!zone) return null;
  const extraRules = [
    { active: zone.blockJump, label: "Jump", detail: "Jumping blocked", glyph: ArrowUp },
    { active: zone.blockMelee, label: "Melee", detail: "Melee blocked", glyph: Swords },
    { active: zone.blockGrenades, label: "Grenades", detail: "Grenades blocked", glyph: Bomb },
    { active: zone.blockConsumables, label: "Native healing", detail: "Native healing/inhaler hotkeys blocked (RP food and drinks remain usable)", glyph: Pill },
    { active: zone.blockReload, label: "Reload", detail: "Reloading blocked", glyph: RotateCw },
    { active: zone.blockWeaponWheel, label: "Wheel", detail: "Weapon wheel blocked", glyph: CircleDot },
  ].filter(rule => rule.active);
  return <div className="hud-safezone">
    <Icon name="shield" size={17} />
    <div className="hud-safezone__body">
      <span className="hud-safezone__label">SAFE ZONE <b>·</b> PvP blocked</span>
      <strong>{zone.label}</strong>
      {(zone.blockRun || zone.blockShoot || extraRules.length > 0) && <div className="hud-safezone__rules">
        {zone.blockRun && <span><Icon name="footprints" size={11} />Walking only</span>}
        {zone.blockShoot && <span><Crosshair aria-hidden="true" size={11} strokeWidth={2} />Shooting blocked</span>}
        {extraRules.length > 0 && <div className="hud-safezone__extra" aria-label={extraRules.map(rule => rule.detail).join(", ")}>
          <span className="hud-safezone__blocked">BLOCKED</span>
          {extraRules.map(rule => <span key={rule.label} title={rule.detail}><rule.glyph aria-hidden="true" size={10} strokeWidth={2} />{rule.label}</span>)}
        </div>}
      </div>}
    </div>
  </div>;
}
