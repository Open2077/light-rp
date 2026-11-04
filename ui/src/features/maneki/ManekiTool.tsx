import { useEffect, useState } from "react";
import { on } from "@/bridge/open77";
import { PAGE_EVENTS, type ManekiToolState } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import "@/features/freecam/freecam.css";
import "./maneki.css";

/* The staff placement tool's bar for the Maneki-neko (client/core/maneki_editor.lua),
   bottom centre, in the free camera's style. Passive: it never takes the keyboard or
   the cursor; the keys are polled in Lua and fixed (the attack actions are claimed). */

function Key({ children }: { children: string }) {
  return <kbd className={"freecam__key" + (children.length > 1 ? " freecam__key--wide" : "")}>{children}</kbd>;
}

export function ManekiTool() {
  const [state, setState] = useState<ManekiToolState>({ active: false });
  useEffect(() => on<ManekiToolState>(PAGE_EVENTS.maneki, (next) => setState(next?.active ? next : { active: false })), []);
  if (!state.active) return null;
  const size = !state.scale || state.scale <= 1 ? "16 CM" : `×${state.scale} · ${Math.round(16 * state.scale)} CM`;
  const status = state.hovered
    ? `Aimed: ${state.hovered}${state.hoveredFound ? " (you found it)" : ""}. DELETE removes it.`
    : state.aim ? "Ready: LEFT CLICK hides a cat here." : "Aim at a floor, a shelf or a ledge within 35 m.";
  return (
    <div className="freecam maneki-tool" role="status" aria-label="Maneki-neko placement tool">
      <div className="freecam__head">
        <span className="freecam__title"><span className="maneki-tool__dot" /><Icon name="coins" size={15} />MANEKI-NEKO · PLACEMENT</span>
        <span className="freecam__status">{status}</span>
        <span className="freecam__readout"><b>{state.nearby ?? 0}</b> AROUND</span>
        <span className="freecam__readout"><b>{size}</b></span>
        <span className="freecam__readout"><b>{state.yaw ?? 0}°</b> TURN</span>
      </div>
      {state.message && <p className={"maneki-tool__message" + (state.ok === false ? " is-error" : "")}>{state.message}</p>}
      <ul className="freecam__keys">
        <li><span className="freecam__mouse" aria-hidden="true"><i /></span><span>Aim</span></li>
        <li><Key>LMB</Key><span>Hide a cat</span></li>
        <li><span className="freecam__pair"><Key>←</Key><Key>→</Key></span><span>Turn 15°</span></li>
        <li><span className="freecam__pair"><Key>↑</Key><Key>↓</Key></span><span>Size</span></li>
        <li><Key>DEL</Key><span>Remove aimed</span></li>
        <li className="freecam__exit"><Key>BACKSPACE</Key><span>Leave</span></li>
      </ul>
    </div>
  );
}
