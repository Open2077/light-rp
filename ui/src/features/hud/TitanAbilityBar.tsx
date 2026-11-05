import { ChevronsRight, ChevronsUp, Crosshair, Flame, LocateFixed, Plane, RotateCw, type LucideIcon } from "lucide-react";
import type { TitanAbilityCell, TitanKit } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import missiles from "./titan-icons/titan-missiles.png?no-inline";
import sentry from "./titan-icons/titan-sentry.png?no-inline";
import smoke from "./titan-icons/titan-smoke.png?no-inline";
import vortex from "./titan-icons/titan-vortex.png?no-inline";
import "./titan-bar.css";

const finite = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);
const share = (v: unknown) => finite(v) ? Math.max(0, Math.min(1, v)) : 0;
const WORDS = { ready: "READY", active: "ACTIVE", empty: "EMPTY" };
/** The BT-7274 mod's own icons (features/hud/titan-icons), for the abilities its native slots drew; the rest get a line icon. */
const MOD_ICONS: Record<string, string> = { missiles, vortex, smoke, sentry };
const LINE_ICONS: Record<string, LucideIcon> = { dash: ChevronsRight, jets: ChevronsUp, flight: Plane, designator: LocateFixed, spin: RotateCw, core: Flame };

/** An ability's picture: the mod's icon, else a line icon (an id the bar does not know gets a reticle). */
function Art({ id }: { id: string }) {
  const src = MOD_ICONS[id];
  const Line = LINE_ICONS[id] ?? Crosshair;
  return <div className="titan-bar__art">{src ? <img src={src} alt="" draggable={false} /> : <Line strokeWidth={1.5} aria-hidden="true" />}</div>;
}

/** One ability: its key, what it still needs (the seconds of a wait or of a burn) or its charges, a charge bar and its name. */
function Cell({ cell }: { cell: TitanAbilityCell }) {
  const state = cell.state === "active" || cell.state === "empty" ? cell.state : "ready";
  const tone = cell.tone === "yellow" || cell.tone === "red" ? cell.tone : "blue";
  const wait = finite(cell.left) && cell.left > 0 ? cell.left : 0;
  const count = finite(cell.count) ? Math.max(0, Math.round(cell.count)) : undefined;
  // A full cell sends no fill: ready and burning are a full bar, a waiting cell with none an empty one.
  const fill = finite(cell.fill) ? share(cell.fill) : state === "empty" ? 0 : 1;
  return <div className="titan-bar__slot" data-state={state} data-tone={tone} data-ability={cell.id}>
    {cell.key && <kbd>{cell.key}</kbd>}
    <Art id={cell.id} />
    {wait > 0 && count !== undefined && count > 0 && <span className="titan-bar__count">×{count}</span>}
    <div className="titan-bar__value">{wait > 0 ? <b>{wait < 10 ? wait.toFixed(1) : Math.round(wait)}<small>s</small></b> : count !== undefined ? <b>{count}</b> : <span className="titan-bar__word">{WORDS[state]}</span>}</div>
    <div className="titan-bar__charge"><i style={{ width: `${(fill * 100).toFixed(1)}%` }} /></div>
    <span className="titan-bar__name">{cell.name ?? cell.id}</span>
  </div>;
}

/** The burst core: it fills from kills (a mark on the bar is the shot's cost); READY is a hazard stripe, ACTIVE the burst burning. */
function Core({ core }: { core: NonNullable<TitanKit["core"]> }) {
  const state = core.state === "ready" || core.state === "active" ? core.state : "charging";
  const charge = share(core.share);
  return <div className="titan-bar__slot titan-bar__slot--core" data-state={state} data-ability={core.ability ?? "core"}>
    {core.key && <kbd>{core.key}</kbd>}
    <Art id={core.ability ?? "core"} />
    <div className="titan-bar__value">{state === "charging" ? <b>{Math.round(charge * 100)}<small>%</small></b> : <span className="titan-bar__word">{state === "ready" ? "READY" : "ACTIVE"}</span>}</div>
    <div className="titan-bar__charge"><i style={{ width: `${(charge * 100).toFixed(1)}%` }} />{finite(core.need) && <u style={{ left: `${(share(core.need) * 100).toFixed(1)}%` }} />}</div>
    <span className="titan-bar__name">{core.name ?? "Core"}</span>
  </div>;
}

/** The Titan's ability bar (hud.titanKit, client/core/hud.lua): while the player pilots one it stands where the quick items sit,
 *  always shown: a tile per ability the class may use, in order, then the burst core. Lua sends an empty list as {}. */
export function TitanAbilityBar() {
  const titan = useStore((s) => s.hud.titan);
  const kit = useStore((s) => s.hud.titanKit);
  const cells = Array.isArray(kit?.abilities) ? kit.abilities : [];
  if (!titan || (cells.length === 0 && !kit?.core)) return null;
  return <div className="titan-bar" data-testid="titan-ability-bar" data-held={titan.held}>
    <div className="titan-bar__slots">
      {cells.map((cell) => <Cell key={cell.id} cell={cell} />)}
      {kit?.core && <Core core={kit.core} />}
    </div>
  </div>;
}
