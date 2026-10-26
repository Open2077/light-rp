import { ArrowUp, Bomb, CircleDot, Crosshair, Pill, RotateCw, Swords } from "lucide-react";
import { Icon } from "@/design/components";
import { useStore } from "@/state/store";
import "./safezone-status.css";

/** Lives inside the gameplay HUD, so creation and tutorial visibility stay consistent. */
export function SafezoneStatus() {
  const zone = useStore(state => state.safezone);
  if (!zone) return null;
  const extraRules = [
    { active: zone.blockJump, label: "Saut", detail: "Saut interdit", glyph: ArrowUp },
    { active: zone.blockMelee, label: "Mêlée", detail: "Corps à corps interdit", glyph: Swords },
    { active: zone.blockGrenades, label: "Grenades", detail: "Grenades interdites", glyph: Bomb },
    { active: zone.blockConsumables, label: "Soins natifs", detail: "Consommables natifs interdits (hors aliments et boissons RP)", glyph: Pill },
    { active: zone.blockReload, label: "Recharge", detail: "Rechargement interdit", glyph: RotateCw },
    { active: zone.blockWeaponWheel, label: "Roue", detail: "Roue des armes bloquée", glyph: CircleDot },
  ].filter(rule => rule.active);
  return <div className="hud-safezone">
    <Icon name="shield" size={17} />
    <div className="hud-safezone__body">
      <span className="hud-safezone__label">ZONE PROTÉGÉE <b>·</b> PvP désactivé</span>
      <strong>{zone.label}</strong>
      {(zone.blockRun || zone.blockShoot || extraRules.length > 0) && <div className="hud-safezone__rules">
        {zone.blockRun && <span><Icon name="footprints" size={11} />Marche uniquement</span>}
        {zone.blockShoot && <span><Crosshair aria-hidden="true" size={11} strokeWidth={2} />Tirs interdits</span>}
        {extraRules.length > 0 && <div className="hud-safezone__extra" aria-label={extraRules.map(rule => rule.detail).join(", ")}>
          <span className="hud-safezone__blocked">BLOQUÉS</span>
          {extraRules.map(rule => <span key={rule.label} title={rule.detail}><rule.glyph aria-hidden="true" size={10} strokeWidth={2} />{rule.label}</span>)}
        </div>}
      </div>}
    </div>
  </div>;
}
