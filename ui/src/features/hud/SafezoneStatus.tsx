import { Crosshair } from "lucide-react";
import { Icon } from "@/design/components";
import { useStore } from "@/state/store";
import "./safezone-status.css";

/** Lives inside the gameplay HUD, so creation and tutorial visibility stay consistent. */
export function SafezoneStatus() {
  const zone = useStore(state => state.safezone);
  if (!zone) return null;
  return <div className="hud-safezone">
    <Icon name="shield" size={17} />
    <div className="hud-safezone__body">
      <span className="hud-safezone__label">ZONE PROTÉGÉE <b>·</b> PvP désactivé</span>
      <strong>{zone.label}</strong>
      {(zone.blockRun || zone.blockShoot) && <div className="hud-safezone__rules">
        {zone.blockRun && <span><Icon name="footprints" size={11} />Marche uniquement</span>}
        {zone.blockShoot && <span><Crosshair aria-hidden="true" size={11} strokeWidth={2} />Tirs interdits</span>}
      </div>}
    </div>
  </div>;
}
