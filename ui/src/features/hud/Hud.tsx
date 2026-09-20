import { useStore } from "@/state/store";
import { Badge, StatusChip, VitalBar } from "@/design/components";
import { useEffect, useState } from "react";
import { WalkFlash } from "./WalkFlash";
import { PlayerVitals } from "./PlayerVitals";
import "./hud.css";

/* Gameplay overlay, inside the HUD safe area: bottom-left vitals, bottom-right
   vehicle cluster (above the voice plate) with the rental countdown while a car
   is out. No status rail: identity and money live in the F1 menu. */
function countdown(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  return `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
}

export function Hud() {
  const hud = useStore((s) => s.hud);
  const character = useStore((s) => s.state.character);
  const inventoryOpen = useStore((s) => s.dialog?.kind === "inventory");
  const rental = useStore((s) => s.state.rental);
  const rentalAt = useStore((s) => s.rentalReceivedAt);
  const [, tick] = useState(0);
  useEffect(() => {
    if (!rental.active) return;
    const timer = setInterval(() => tick((t) => t + 1), 1000);
    return () => clearInterval(timer);
  }, [rental.active]);
  if (!hud.ready || (useStore.getState().connected && character.status !== "active")) return null;

  return (
    <div className={`hud${inventoryOpen ? " hud--quiet" : ""}`} aria-hidden="true">
      <WalkFlash />
      <div className="hud__bottom-left">
        <PlayerVitals />
      </div>

      <div className="hud__bottom-right">
        {rental.active && <StatusChip icon="car" label="RENTAL" tone="accent" value={countdown(rental.active.remainingMs - (Date.now() - rentalAt))} />}
        {hud.vehicle.active && (
        <div className="hud__vehicle">
          <div className="hud__speed">
            <span className="hud__speed-value">{String(Math.round(hud.vehicle.speedKph ?? 0)).padStart(3, "0")}</span>
            <span className="hud__speed-unit">KM/H</span>
          </div>
          <div className="hud__vehicle-meta">
            <span className="o77-readout o77-dim">{hud.vehicle.label ?? "VEHICLE"}</span>
            <Badge tone="accent">{hud.vehicle.gear ?? "N"}</Badge>
          </div>
          <VitalBar tone="accent" label="CONDITION" value={(hud.vehicle.health ?? 1) * 100} size="sm" width={140} segments={14} />
        </div>
        )}
      </div>
    </div>
  );
}
