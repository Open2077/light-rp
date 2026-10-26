import { useStore } from "@/state/store";
import { StatusChip } from "@/design/components";
import { VehicleCluster } from "./VehicleCluster";
import { useEffect, useState } from "react";
import { WalkFlash } from "./WalkFlash";
import { PlayerVitals } from "./PlayerVitals";
import { SafezoneStatus } from "./SafezoneStatus";
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
  const tutorial = useStore((s) => s.state.tutorial);
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
  if (tutorial?.active && (tutorial.step === "intro" || tutorial.dialogue)) return null;

  return (
    <div className={`hud${inventoryOpen ? " hud--quiet" : ""}`} aria-hidden="true">
      <WalkFlash />
      <div className="hud__bottom-left">
        <SafezoneStatus />
        <PlayerVitals />
      </div>

      <div className="hud__bottom-right">
        {rental.active && <StatusChip icon="car" label="RENTAL" tone="accent" value={countdown(rental.active.remainingMs - (Date.now() - rentalAt))} />}
        {hud.vehicle.active && <VehicleCluster vehicle={hud.vehicle} />}
      </div>
    </div>
  );
}
