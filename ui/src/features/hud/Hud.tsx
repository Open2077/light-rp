import { useStore } from "@/state/store";
import { Badge, MicIndicator, StatusChip, VitalBar } from "@/design/components";
import { sendAction } from "@/bridge/open77";
import "./hud.css";

/* Gameplay overlay, inside the HUD safe area. Layout contract from the design
   system's in-game-hud kit: bottom-left vitals + voice, top-right status rail,
   bottom-right vehicle cluster while seated. The centre stays clear. */
export function Hud() {
  const hud = useStore((s) => s.hud);
  const character = useStore((s) => s.state.character);
  const needs = useStore((s) => s.state.needs);
  const server = useStore((s) => s.state.server);
  const staff = useStore((s) => s.state.staff);
  const menuOpen = useStore((s) => s.menuOpen);

  if (!hud.ready || menuOpen) return null;
  const name = character.registered ? `${character.firstName} ${character.lastName}` : character.accountName;

  return (
    <div className="hud" aria-hidden="true">
      <div className="hud__top-right">
        <StatusChip icon="id-card" label="ID" value={String(character.playerId).padStart(3, "0")} />
        <StatusChip icon="users" label="EN VILLE" value={`${server.playersOnline}/${server.maxPlayers}`} />
        <StatusChip label="" value={hud.clock} tone="accent" />
        {staff.isStaff && <Badge tone="danger">STAFF</Badge>}
        {!character.registered && <Badge tone="outline">/REGISTER</Badge>}
      </div>

      <div className="hud__bottom-left">
        <div className="hud__identity">
          <span className="hud__wordmark">Open<span>//</span>77</span>
          <span className="hud__name">{name}</span>
        </div>
        <div className="hud__vitals">
          <VitalBar tone="health" value={hud.health.value} max={hud.health.max} />
          <VitalBar tone="armor" value={hud.armor} max={100} size="sm" showValue={false} />
          <VitalBar tone="stamina" value={hud.stamina.value} max={hud.stamina.max} size="sm" showValue={false} />
          <div className="hud__needs">
            <VitalBar tone="food" value={needs.food} size="sm" width={78} segments={10} />
            <VitalBar tone="drink" value={needs.drink} size="sm" width={78} segments={10} />
          </div>
        </div>
        <MicIndicator state={hud.voice.state} level={hud.voice.level} range={hud.voice.range}
          rangeMetres={{ whisper: 4, normal: 15, shout: 40 }}
          onRangeChange={(range) => sendAction({ type: "voice.range", range })} />
      </div>

      {hud.vehicle.active && (
        <div className="hud__bottom-right">
          <div className="hud__speed">
            <span className="hud__speed-value">{String(Math.round(hud.vehicle.speedKph ?? 0)).padStart(3, "0")}</span>
            <span className="hud__speed-unit">KM/H</span>
          </div>
          <div className="hud__vehicle-meta">
            <span className="o77-readout o77-dim">{hud.vehicle.label ?? "VEHICLE"}</span>
            <Badge tone="accent">{hud.vehicle.gear ?? "N"}</Badge>
          </div>
          <VitalBar tone="accent" label="ETAT" value={(hud.vehicle.health ?? 1) * 100} size="sm" width={140} segments={14} />
        </div>
      )}
    </div>
  );
}
