import { useEffect, useState } from "react";
import { on } from "@/bridge/open77";
import { PAGE_EVENTS, type FreecamState } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import "./freecam.css";

/* The free camera's reminder bar, bottom centre: what flies the lens, with the
   keys the player really has (every one is a rebindable mapping), and how far
   the lens is from the character against the radius it may not leave. Passive:
   it never takes the keyboard or the cursor. */

const ALIASES: Record<string, string> = { FORWARD: "KeyW", BACK: "KeyS", STRAFE_LEFT: "KeyA", STRAFE_RIGHT: "KeyD" };
const NAMES: Record<string, string> = { BACKSPACE: "BKSP", CONTROL: "CTRL", RETURN: "ENTER", PAGEUP: "PGUP", PAGEDOWN: "PGDN", MOUSE1: "LMB", MOUSE2: "RMB", MOUSE3: "MMB" };

/** Movement aliases follow the keyboard layout: WASD, or ZQSD on AZERTY. */
function useLayout(): Record<string, string> {
  const [layout, setLayout] = useState<Record<string, string>>({ KeyW: "W/Z", KeyS: "S", KeyA: "A/Q", KeyD: "D" }); // until the layout answers
  useEffect(() => {
    const keyboard = (navigator as Navigator & { keyboard?: { getLayoutMap?: () => Promise<Map<string, string>> } }).keyboard;
    let alive = true;
    keyboard?.getLayoutMap?.().then((map) => {
      if (!alive) return;
      const next: Record<string, string> = {};
      for (const code of Object.values(ALIASES)) next[code] = (map.get(code) ?? code.slice(3)).toUpperCase();
      setLayout(next);
    }).catch(() => undefined);
    return () => { alive = false; };
  }, []);
  return layout;
}

function Key({ children, wide }: { children: string; wide?: boolean }) {
  return <kbd className={"freecam__key" + (wide || children.length > 1 ? " freecam__key--wide" : "")}>{children}</kbd>;
}

export function Freecam() {
  const [state, setState] = useState<FreecamState>({ active: false });
  const layout = useLayout();
  useEffect(() => on<FreecamState>(PAGE_EVENTS.freecam, (next) => setState(next?.active ? next : { active: false })), []);
  if (!state.active) return null;

  const label = (name: string): string => {
    const raw = String(state.keys?.[name] ?? "?").toUpperCase();
    const code = ALIASES[raw];
    return code ? layout[code] ?? code.slice(3) : NAMES[raw] ?? raw;
  };
  const radius = state.radius ?? 0;
  const distance = Math.min(state.distance ?? 0, radius);
  const ratio = radius > 0 ? distance / radius : 0;
  const range = ratio >= 0.995 ? "limit" : ratio >= 0.8 ? "near" : "ok";
  const preparing = state.phase !== "active";

  if (state.hints === false) {
    return (
      <div className="freecam freecam--quiet" role="status" aria-label="Free camera">
        <span className="freecam__dot" /><span>FREE CAMERA</span><Key>{label("hints")}</Key><span>KEYS</span>
      </div>
    );
  }
  return (
    <div className={"freecam" + (state.paused ? " freecam--paused" : "")} role="status" aria-label="Free camera">
      <div className="freecam__head">
        <span className="freecam__title"><span className="freecam__dot" /><Icon name="video" size={15} />FREE CAMERA</span>
        <span className="freecam__status">{preparing ? "Stepping out of your view…" : state.paused ? "Paused while a menu is open" : "Your character stays where it is"}</span>
        <span className={`freecam__range freecam__range--${range}`} aria-label={`Lens ${distance.toFixed(1)} of ${radius} metres from your character`}>
          <span className="freecam__range-text"><b>{distance.toFixed(1)}</b> / {radius} M</span>
          <span className="freecam__gauge"><i style={{ width: `${Math.round(ratio * 100)}%` }} /></span>
          <span className="freecam__range-note">{range === "limit" ? "RANGE LIMIT" : "RANGE"}</span>
        </span>
        <span className="freecam__readout"><b>{(state.speed ?? 0).toFixed(1)}</b> M/S</span>
        <span className="freecam__readout"><b>{state.fov ?? 0}</b>° LENS</span>
      </div>
      <ul className="freecam__keys">
        <li>
          <span className="freecam__cross">
            <Key>{label("forward")}</Key>
            <span><Key>{label("left")}</Key><Key>{label("back")}</Key><Key>{label("right")}</Key></span>
          </span>
          <span>Move</span>
        </li>
        <li><span className="freecam__mouse" aria-hidden="true"><i /></span><span>Look around</span></li>
        <li><span className="freecam__pair"><Key>{label("up")}</Key><Key>{label("down")}</Key></span><span>Up / down</span></li>
        <li><span className="freecam__mouse freecam__mouse--wheel" aria-hidden="true"><i /></span><span>Speed</span></li>
        <li><Key>{label("boost")}</Key><span>Fast</span></li>
        <li><span className="freecam__pair"><Key>{label("slow")}</Key><span className="freecam__plus">+</span><span className="freecam__mouse freecam__mouse--wheel" aria-hidden="true"><i /></span></span><span>Precise · zoom</span></li>
        <li><Key>{label("reset")}</Key><span>Behind me</span></li>
        <li><Key>{label("hints")}</Key><span>Hide keys</span></li>
        <li className="freecam__exit"><span className="freecam__pair"><Key>{label("exit")}</Key><Key>{label("toggle")}</Key></span><span>Leave</span></li>
      </ul>
    </div>
  );
}
